#!/usr/bin/ruby

require 'pry'
require 'chip-gpio'

require 'prometheus/client'
require 'sinatra'
require 'rack'
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'

use Rack::Deflater, if: ->(_, _, _, body) { body.any? && body[0].length > 512 }
use Prometheus::Middleware::Collector
use Prometheus::Middleware::Exporter

class TMP36

  def temperature
    # http://www.eu.diigiit.com/download/TMP35-36-37.pdf
    # 750mV at 25C; +-10mV per 1C
    @temperature = 25.0 + (voltage - 750) / 10.0
  end

  # return voltage in mV
  def voltage
    lfac_device = '/sys/bus/iio/devices/iio:device0/'
    raw_voltage = File.read(File.join(lfac_device, 'in_voltage0_raw')).strip.to_f
    scale = File.read(File.join(lfac_device, 'in_voltage_scale')).strip.to_f
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

class Heater

  def initialize(pin: :XIO7)
    pins = ChipGPIO.get_pins
    @pin = pins[pin]

    @pin.export unless @pin.available?
    @pin.direction = :output
  end

  def start
    @pin.value = 1
  end

  def stop
    @pin.value = 0
  end

  def started?
    @pin.value == 1
  end
end

set :port, $PORT0

prometheus = Prometheus::Client.registry
temperature = prometheus.gauge(:temperature_celcius, 'Current temperature')
heater = Heater.new
thermometer = TMP36.new
stable_thermometer = MovingAverageThermometer.new(size: 100)

before do
  content_type :json
end

get '/temperature' do
  {temperature: stable_thermometer.temperature.round(1)}.to_json
end

post '/heating' do
  req_body = request.body.read
  case req_body
  when 'ON'
    heater.start
    {ok: true}.to_json
  when 'OFF'
    heater.stop
    {ok: true}.to_json
  else
    halt 400, {ok: false, error: "Unknown order: #{req_body.inspect}" }.to_json
  end
end

get '/heating' do
  if heater.started?
    'ON'
  else
    'OFF'
  end
end

Thread.new do
  i = 0
  loop do
    begin
    stable_thermometer.record(thermometer.temperature)
    temperature.set({}, thermometer.temperature)
    puts stable_thermometer.temperature if i % 10 == 0
    rescue => e
      puts e
    end
    sleep 0.1 # TODO increase period to limit consumption
    i = (i + 1) % 1000
  end
end
