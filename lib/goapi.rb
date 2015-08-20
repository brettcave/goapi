require "goapi/version"
require "goapi/http"
require 'logger'
require 'json'
require 'time'
require 'uri'

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

  def initialize(server, credentials)
    @server, @http = server, Http.new(credentials)
  end

  def stages(pipeline, stage)
    Stages.new(fetch(:api, :stages, pipeline, stage, :history))
  end

  # stage: object from stages
  # job_name: job name, can be found in stage.jobs
  def job_properties(stage, job_name)
    text = @http.get(url(:properties, stage.pipeline_name, stage.pipeline_counter, stage.name, stage.counter, job_name))[1]
    names, values = text.split("\n")
    values = values.split(',')
    OpenStruct.new(Hash[names.split(',').each_with_index.map do |name, i|
      [name, values[i]]
    end])
  end

  # stage: object from stages
  # job_name: job name, can be found in stage.jobs
  def artifacts(stage, job_name)
    fetch(:files, stage.pipeline_name, stage.pipeline_counter, stage.name, stage.counter, "#{job_name}.json")
  end

  # artifact: object from artifacts(stage, job_name)
  def artifact(artifact)
    raise "Only accept file type artifact" if artifact.type != 'file'
    u = URI(artifact.url)
    @http.get([@server, u.path].join('/'))[1]
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
