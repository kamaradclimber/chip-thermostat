#!/usr/bin/ruby

require 'pry'



class TMP36

  def temperature
    # http://www.eu.diigiit.com/download/TMP35-36-37.pdf
    # 750mV at 25C; +-10mV per 1C
    @temperature = 25.0 + (voltage - 750) / 10.0
  end

  # return voltage in mV
  def voltage
    raw_voltage = File.read('/sys/bus/iio/devices/iio:device0/in_voltage0_raw').strip.to_f
    scale = File.read('/sys/bus/iio/devices/iio:device0/in_voltage_scale').strip.to_f
    @voltage = raw_voltage * scale
  end

  def inspect
    "voltage: #{@voltage}mV, temperature: #{@temperature}C"
  end
end

class MovingAverageThermometer
  def initialize(size:)
    @observations = []
    @size = size
    @sum = 0.0
    @index = 0
  end

  def record(temperature)
    if @observations.size < @size
      @observations << temperature
    else
      old = @observations[@index]
      @observations[@index] = temperature
      @sum -= old
    end
    @sum += temperature
    @index = (@index + 1) % @size
  end

  def inspect
    @observations.inspect
  end

  def temperature
    @sum / @observations.size
  end
end

thermometer = TMP36.new
stable_thermometer = MovingAverageThermometer.new(size: 100)
i = 0
loop do
  stable_thermometer.record(thermometer.temperature)
  puts stable_thermometer.temperature if i % 10 == 0
  sleep 0.1 # TODO increase period to limit consumption
  i = (i + 1) % 1000
end
