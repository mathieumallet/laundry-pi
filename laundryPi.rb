#!/usr/bin/env ruby

require 'optparse'

# Defaults
options = {}
options[:command] = "pinctrl"
options[:checkPeriod] = "100" # in milliseconds
options[:samplesCount] = "10"
options[:numerOfRequiredPositiveSamples] = "2"

optparser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [OPTIONS]"
    opts.separator ""
    opts.separator "This periodically queries a set of GPIO pins and reports their status on an HTTP server."
    opts.separator ""
    opts.separator "OPTIONS"

    opts.on('-h', '--help', "Prints this message.") { puts optparser.help(); exit 1 }
    opts.on('-c', '--command', "If provided, Uses the specified app to check for pin status. Defaults to '#{options[:command]}'.") { |value| options[:command] = value }
    opts.on('-p pin1,pin2', '--pins pin1,pin2', Array, "Specifies the set of pins to monitor. At least one pin must be specified.") { |list| options[:pins] = list }
    opts.on('--check-period', "Specifies the rate, in milliseconds, at which checks are made. Defaults to #{options[:checkPeriod]} ms.") { |value| options[:checkPeriod] = value }
    opts.on('--samples-count', "Specifies the number of samples that are combined together together. Defaults to #{options[:samplesCount]}.") { |value| options[:samplesCount] = value }
    opts.on('--positive-samples-needed', "Specifies the number of samples that need to be 'high' for the output to be 'true'. Defaults to #{options[:numerOfRequiredPositiveSamples]}.") { |value| options[:numerOfRequiredPositiveSamples] = value }
end
optparser.parse!

if !options[:pins]
    puts optparser.help()
    exit 1
end
