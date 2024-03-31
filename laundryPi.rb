#!/usr/bin/env ruby

# This script polls GPIO pins and uses a rolling window to calculate if the
# pins should be considered 'high' or 'low'. It is meant to clean up the
# output of a noisy vibration sensor. Those values are then further filtered.
# The computed value and filtered value are then output by HTTP to a specified
# port.
#
# By default, the HTTP output can be accessed from http://ip:8080/
#
# The HTTP output is in the form:
#
# # Pin NUMBER: CURRENT_STATE, FILTERED_STATE
# Pin 14: false, true
# Pin 4: true, true
#

# Defaults
options = {}
options[:command] = "pinctrl"
options[:checkPeriod] = 10 # in milliseconds
options[:samplesCount] = 1000
options[:numberOfRequiredStateChanges] = 20
options[:filterSize] = 30000
options[:verbose] = false
options[:port] = 8080

require 'optparse'
require 'socket'

optparser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS]"
    opts.separator ""
    opts.separator "This periodically queries a set of GPIO pins and reports their status on an HTTP server."
    opts.separator ""
    opts.separator "OPTIONS"

    opts.on('-h', '--help', "Prints this message.") { puts optparser.help(); exit 1 }
    opts.on('-c', '--command CMD', "If provided, Uses the specified app to check for pin status. Defaults to '#{options[:command]}'.") { |value| options[:command] = value }
    opts.on('-p pin1,pin2', '--pins pin1,pin2', Array, "Specifies the set of pins to monitor. At least one pin must be specified.") { |list| options[:pins] = list }
    opts.on('--check-period PERIOD', "Specifies the rate, in milliseconds, at which checks are made. Defaults to #{options[:checkPeriod]} milliseconds.") { |value| options[:checkPeriod] = value.to_i }
    opts.on('--samples-count COUNT', "Specifies the number of samples that are combined together together. Defaults to #{options[:samplesCount]}.") { |value| options[:samplesCount] = value.to_i }
    opts.on('--state-changes-needed CHANGES', "Specifies the number of state changes in the samples that are needed for the output to be 'true'. Defaults to #{options[:numberOfRequiredStateChanges]}.") { |value| options[:numberOfRequiredStateChanges] = value.to_i }
    opts.on('--filter-size SIZE', "Additional filtering done on the output. At least SIZE values must be identical in a row before the filtered output changes. Defaults to #{options[:filterSize]}.") { |value| options[:filterSize] = value.to_i }
    opts.on('--port PORT', "The port on which the results should be offered. Set to 0 to disable the HTTP server. Defaults to #{options[:port]}.") { |value| options[:port] = value.to_i }
    opts.on('-v', '--verbose', "Log more to the screen.") { options[:verbose] = true }
end
optparser.parse!

if !options[:pins]
    puts optparser.help()
    exit 1
end

# Convert arguments to integers
options[:pins].map!(&:to_i)
pinsList = options[:pins].join(",")

# Print settings
puts "Listener started."
puts "Command: #{options[:command]}"
puts "Pins: #{options[:pins]}"
puts "Check period: #{options[:checkPeriod]} milliseconds"
puts "Samples count: #{options[:samplesCount]} (#{(options[:checkPeriod] * options[:samplesCount]) / 1000} seconds)"
puts "Needed state changes: #{options[:numberOfRequiredStateChanges]} (#{options[:numberOfRequiredStateChanges].to_f / options[:samplesCount] * 100} %)"
puts "Filter size: #{options[:filterSize]} (#{(options[:filterSize] * options[:checkPeriod]) / 1000} seconds)"
puts

# Prepare data objects
pinsSamples = {}
pinsLastState = {}
pinsComputedState = {}
pinsFilteredSamples = {}
pinsFilteredLastState = {}
for pin in options[:pins]
    pinsSamples[pin] = Array.new(options[:samplesCount], 0)
    pinsLastState[pin] = 0
    pinsComputedState[pin] = false

    pinsFilteredSamples[pin] = Array.new(options[:filterSize], 0)
    pinsFilteredLastState[pin] = 0
end

# Setup HTTP server
if options[:port] != 0
    socket = TCPServer.new(options[:port])
    throw "Could not open socket on port #{options[:port]}" unless socket
    Thread.new {
        puts "Listening for HTTP connections on port #{options[:port]}"
        while true
            client = socket.accept
            request = client.gets
            client.puts("HTTP/1.1 200\r\n\r\n")
            client.puts("# Pin NUMBER: CURRENT_STATE, FILTERED_STATE")
            pinsComputedState.each{|pin,value|
                client.puts "Pin #{pin}: #{value}, #{pinsFilteredLastState[pin] != 0}"
            }
            client.close
        end
    }
end

# Main querying loop
while true
    # Query values
    output = `#{options[:command]} get #{pinsList}`
    throw "Command execution failed: #{options[:command]}" unless output

    # Parse output
    lines = output.split(/\n/)
    for line in lines
        # Extract pin and value from line
        line.strip!
        values = line.scan(/\w+/)
        pin = values[0].to_i
        value = values[2]
        throw "Unexpected pin value: #{value}" unless value == "hi" || value == "lo"
        throw "Unexpected pin: #{pin}" unless options[:pins].include?(pin)
        puts "[#{Time.new}]  Raw output from command: #{line}" if options[:verbose]

        value = value == "hi" ? 1 : 0
        puts "[#{Time.new}]  Previous pin value: #{pinsLastState[pin]}; new pin value: #{value}" if options[:verbose]
        valueChanged = pinsLastState[pin] != value ? 1 : 0
        pinsLastState[pin] = value

        # Update samples array
        samples = pinsSamples[pin]
        samples.shift # remove first item
        samples.push(valueChanged)
        puts "[#{Time.new}]  Current samples for #{pin}: #{samples}" if options[:verbose]

        # Calculate new value
        total = samples.sum
        pinIsHigh = total >= options[:numberOfRequiredStateChanges]
        puts "[#{Time.new}]  Pin #{pin} calculated state: #{pinIsHigh} (sum of #{total})" if options[:verbose]

        # Notify on console if the value changed (+ update the saved value)
        if pinIsHigh != pinsComputedState[pin]
            puts "[#{Time.new}]  Calculated state of pin #{pin} changed to #{pinIsHigh}"
            pinsComputedState[pin] = pinIsHigh
        end

        # Apply filtering
        samples = pinsFilteredSamples[pin]
        samples.shift # remove first item
        samples.push(pinsComputedState[pin] ? 1 : 0)
        puts "[#{Time.new}]  Current filtered samples for #{pin}: #{samples}" if options[:verbose]
        sum = samples.sum
        if sum == 0 || sum == options[:filterSize]
            if sum != pinsFilteredLastState[pin]
                puts "[#{Time.new}]  Filtered state of pin #{pin} changed to #{sum == 0 ? false : true}"
                pinsFilteredLastState[pin] = sum
            end
        end
        puts "[#{Time.new}]  Filtered state of pin #{pin}: #{pinsFilteredLastState[pin] == 0 ? false : true} (sum of #{sum})" if options[:verbose]
    end

    # Sleep
    sleep(options[:checkPeriod] / 1000.0)

    puts if options[:verbose]

end
