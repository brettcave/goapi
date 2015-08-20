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

  def artifacts(pipeline, pipeline_counter, stage, stage_counter, job_name)
    fetch(:files, pipeline, pipeline_counter, stage, stage_counter, "#{job_name}.json")
  end

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
