#!/usr/bin/env ruby

# This script polls GPIO pins and uses a rolling window to calculate if the
# pins should be considered 'high' or 'low'. It is meant to clean up the
# output of a noisy vibration sensor. The computed value is then output by
# HTTP to a specified port.
#
# By default, the HTTP output can be accessed from http://ip:8080/
#
# The HTTP output is in the form:
# Pin 14: false
# Pin 4: true
#

# Defaults
options = {}
options[:command] = "pinctrl"
options[:checkPeriod] = 100 # in milliseconds
options[:samplesCount] = 10
options[:numerOfRequiredPositiveSamples] = 2
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
    opts.on('--positive-samples-needed SAMPLES', "Specifies the number of samples that need to be 'high' for the output to be 'true'. Defaults to #{options[:numerOfRequiredPositiveSamples]}.") { |value| options[:numerOfRequiredPositiveSamples] = value.to_i }
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
puts "Samples count: #{options[:samplesCount]}"
puts "Positive samples needed: #{options[:numerOfRequiredPositiveSamples]}"
puts

# Prepare data objects
pinsSamples = {}
pinsState = {}
for pin in options[:pins]
    samples = Array.new(options[:samplesCount], 0)
    pinsSamples[pin] = samples
    pinsState[pin] = false
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
            pinsState.each{|pin,value|
                client.puts "Pin #{pin}: #{value}"
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

        # Update samples array
        samples = pinsSamples[pin]
        samples.shift # remove first item
        samples.push(value == "hi" ? 1 : 0)
        puts "[#{Time.new}]  Current samples for #{pin}: #{samples}" if options[:verbose]

        # Calculate new value
        total = samples.sum
        pinIsHigh = total >= options[:numerOfRequiredPositiveSamples]
        puts "[#{Time.new}]  Pin #{pin} calculated state: #{pinIsHigh}" if options[:verbose]

        # Notify on console if the value changed (+ update the saved value)
        if pinIsHigh != pinsState[pin]
            puts "[#{Time.new}]  Calculated state of pin #{pin} changed to #{pinIsHigh}"
            pinsState[pin] = pinIsHigh
        end
    end

    # Sleep
    sleep(options[:checkPeriod] / 1000.0)

    puts if options[:verbose]

end
