This project is a simple ruby script used to poll and massage Raspberry Pi GPIO inputs.
This was written for use with vibration sensors, whose output is extremely noisy.
The `laundryPi.rb` script polls a set of GPIO inputs, and for each input it stores the last 10 samples.
If at least 2 of the 10 samples are 'high', that GPIO pin is considered 'high'.
The result of the checks are output to the console, and exposed on an HTTP port.

To run:
```
./laundryPi.rb --pins 14,3
```

Sample console output:
```
Listener started.
Command: pinctrl
Pins: [14, 3]
Check period: 100 milliseconds
Samples count: 10
Positive samples needed: 2

Listening for HTTP connections on port 8080
[2024-03-23 14:03:34 -0400]  Calculated state of pin 3 changed to true
[2024-03-23 14:03:39 -0400]  Calculated state of pin 3 changed to false
[2024-03-23 14:03:42 -0400]  Calculated state of pin 14 changed to true
```

By default, results are posted on port 8080.
Sample HTTP output:
```
Pin 14: true
Pin 3: false
```

The script uses the `pinctrl` command to determine if a given pin is 'high' or 'low.
For local testing, the `mockPinctrl.rb` script can be used instead:
```
./laundryPi.rb --pins 14,3 --command ./mockPinctrl.rb
```
