require "goapi/version"
require "goapi/http"
require 'logger'
require 'json'
require 'time'
require 'uri'
require 'ostruct'

class GoAPI

  class Stages
    include Enumerable
    def initialize(data)
      @data = data
    end

    def each(&block)
      @data.stages.each(&block)
    end

    def size
      @data.stages
    end
  end

  class << self
    def logger
      @logger ||= Logger.new(STDOUT)
    end
  end

  # server: Go server url, for example: https://go01.domain.com
  # credentials: 
  #   only support basic auth right now, example: {basic_auth: [username, password]}
  #   default value is nil
  def initialize(server, credentials=nil)
    @server, @http = server, Http.new(credentials)
  end

  def stages(pipeline_name, stage_name)
    Stages.new(fetch(:api, :stages, pipeline_name, stage_name, :history))
  end

  # stage:
  #   object has attribute methods: pipeline_name, pipeline_counter, name, counter
  #   You can get this object by calling stages(pipeline_name, stage_name)
  # job_name: job name
  def job_properties(stage, job_name)
    text = @http.get(url(:properties, stage.pipeline_name, stage.pipeline_counter, stage.name, stage.counter, job_name))[1]
    names, values = text.split("\n")
    values = values.split(',')
    OpenStruct.new(Hash[names.split(',').each_with_index.map do |name, i|
      [name, values[i]]
    end])
  end

  # stage:
  #   object has attribute methods: pipeline_name, pipeline_counter, name, counter
  #   You can get this object by calling stages(pipeline_name, stage_name)
  # job_name: job name
  def artifacts(stage, job_name)
    fetch(:files, stage.pipeline_name, stage.pipeline_counter, stage.name, stage.counter, "#{job_name}.json")
  end

  # artifact: object from artifacts(stage, job_name), it should have 2 attributes "type" and "url", and "type" should be "file"
  def artifact(artifact)
    raise "Only accept file type artifact" if artifact.type != 'file'
    u = URI(artifact.url)
    @http.get([@server, u.path].join('/'))[1]
  end

  # build stage uniq identifier for stage object
  def stage_id(stage)
    "#{stage.pipeline_name}/#{stage.pipeline_counter}/#{stage.name}/#{stage.counter}"
  end

  private
  def fetch(*resources)
    ostruct(JSON.parse(@http.get(url(*resources))[1]))
  end

  def url(*resources)
    [@server, :go, *resources].join('/')
  end

  def ostruct(o)
    case o
    when Array
      o.map(&method(:ostruct))
    when Hash
      r = o.map do |k, v|
        [k, ostruct(v)]
      end
      OpenStruct.new(Hash[r])
    else
      o
    end
  end
end
