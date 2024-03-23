#!/usr/bin/env ruby

require 'optparse'

# Defaults
options = {}
options[:command] = "pinctrl"
options[:checkPeriod] = 100 # in milliseconds
options[:samplesCount] = 10
options[:numerOfRequiredPositiveSamples] = 2

optparser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS]"
    opts.separator ""
    opts.separator "This periodically queries a set of GPIO pins and reports their status on an HTTP server."
    opts.separator ""
    opts.separator "OPTIONS"

    opts.on('-h', '--help', "Prints this message.") { puts optparser.help(); exit 1 }
    opts.on('-c', '--command CMD', "If provided, Uses the specified app to check for pin status. Defaults to '#{options[:command]}'.") { |value| options[:command] = value }
    opts.on('-p pin1,pin2', '--pins pin1,pin2', Array, "Specifies the set of pins to monitor. At least one pin must be specified.") { |list| options[:pins] = list }
    opts.on('--check-period PERIOD', "Specifies the rate, in milliseconds, at which checks are made. Defaults to #{options[:checkPeriod]} ms.") { |value| options[:checkPeriod] = value.to_i }
    opts.on('--samples-count COUNT', "Specifies the number of samples that are combined together together. Defaults to #{options[:samplesCount]}.") { |value| options[:samplesCount] = value.to_i }
    opts.on('--positive-samples-needed SAMPLES', "Specifies the number of samples that need to be 'high' for the output to be 'true'. Defaults to #{options[:numerOfRequiredPositiveSamples]}.") { |value| options[:numerOfRequiredPositiveSamples] = value.to_i }
end
optparser.parse!

if !options[:pins]
    puts optparser.help()
    exit 1
end

# Convert arguments to integers
options[:pins].map!(&:to_i)
pinsList = options[:pins].join(",")

# TODO: print settings on launch

pinsData = {}
for pin in options[:pins]
    samples = Array.new(options[:samplesCount], 0)
    pinsData[pin] = samples
end

# Main loop
while true
    # Query values
    puts "Checking..."
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

        # Update samples array
        samples = pinsData[pin]
        samples.shift # remove first item
        samples.push(value == "hi" ? 1 : 0)
        puts "samples for pin #{pin}: #{samples}"

        # Calculate new value
        total = samples.sum
        pinIsHigh = total >= options[:numerOfRequiredPositiveSamples]
        puts "pin #{pin} high? #{pinIsHigh}"

        # TODO store value and expose to HTTP
    end

    # Sleep
    sleep(options[:checkPeriod] / 1000.0)

    puts

end
