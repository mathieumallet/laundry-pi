#!/usr/bin/env ruby

# This script simulates the pinctrl utility from the pi. Usage:
# mockPinctrl.rb get 14,8,25

throw "Unexpected arguments" unless ARGV.length == 2
throw "Unexpected arguments" unless ARGV[0] == "get"

# Get pins list
pins = ARGV[1].split(",").map(&:to_i).sort

# Sample output from the 'real' pinctrl with args 'get 14,3':
#  3: ip    -- | lo // GPIO3 = input
# 14: ip    -- | lo // GPIO14 = input

for pin in pins
    value = rand(1..10) == 1 ? "hi" : "lo"
    printf("%s: ip    -- | %s // GPIO%s = input\n", pin.to_s.rjust(2), value, pin)
end
