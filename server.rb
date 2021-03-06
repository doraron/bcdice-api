# frozen_string_literal: true
$:.unshift __dir__
$:.unshift File.join(__dir__, "bcdice", "src")
$:.unshift File.join(__dir__, "lib")

require 'sinatra'
require 'sinatra/jsonp'
require "sinatra/reloader" if development?
require 'bcdice_wrap'
require 'load_admin_info'
require 'exception'

module BCDiceAPI
  VERSION = "0.9.0"
end

configure :production do
  set :dump_errors, false
end

helpers do
  def diceroll(system, command)
    dicebot = BCDice::DICEBOTS[system]
    if dicebot.nil?
      raise UnsupportedDicebot
    end
    if command.nil? || command.empty?
      raise CommandError
    end

    bcdice = BCDiceMaker.new.newBcDice
    bcdice.setDiceBot(dicebot)
    bcdice.setMessage(command)
    bcdice.setCollectRandResult(true)

    result, secret = bcdice.dice_command

    if result.nil?
      result, secret = bcdice.try_calc_command(command)
    end

    dices = bcdice.getRandResults.map {|dice| {faces: dice[1], value: dice[0]}}
    detailed_rands = bcdice.detailed_rand_results.map do |dice|
      dice = dice.to_h
      dice[:faces] = dice[:sides]
      dice.delete(:faces)

      dice
    end

    if result.nil?
      raise CommandError
    end

    {
      ok: true,
      result: result,
      secret: secret,
      dices: dices,
      detailed_rands: detailed_rands,
    }
  end
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
end

get "/" do
  "Hello. This is BCDice-API."
end

get "/v1/version" do
  jsonp api: BCDiceAPI::VERSION, bcdice: BCDice::VERSION
end

get "/v1/admin" do
  jsonp BCDiceAPI::ADMIN
end

get "/v1/systems" do
  jsonp systems: BCDice::SYSTEMS
end

get "/v1/names" do
  jsonp names: BCDice::NAMES
end

get "/v1/systeminfo" do
  dicebot = BCDice::DICEBOTS[params[:system]]
  if dicebot.nil?
    raise UnsupportedDicebot
  end

  jsonp ok: true, systeminfo: dicebot.info
end

get "/v1/diceroll" do
  jsonp diceroll(params[:system], params[:command])
end

not_found do
  jsonp ok: false, reason: "not found"
end

error UnsupportedDicebot do
  status 400
  jsonp ok: false, reason: "unsupported dicebot"
end

error CommandError do
  status 400
  jsonp ok: false, reason: "unsupported command"
end

error do
  jsonp ok: false
end
