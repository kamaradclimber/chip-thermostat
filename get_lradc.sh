#!/bin/sh

rawval=`cat /sys/bus/iio/devices/iio:device0/in_voltage0_raw`
scale=`cat /sys/bus/iio/devices/iio:device0/in_voltage_scale`
lradcval=`echo "$rawval * $scale" | bc`

echo "RAW LRADC VALUE: $rawval"
echo "SCALE:           $scale"
echo "LRADC READING:   $lradcval mV"
