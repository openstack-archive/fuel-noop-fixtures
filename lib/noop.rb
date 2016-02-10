require_relative 'noop/utils'
require_relative 'noop/config'
require_relative 'noop/manager'
require_relative 'noop/task'
require_relative 'noop/matchers'

module Noop
  def self.new_task(*args)
    self.task = Noop::Task.new *args
  end

  def self.task_spec=(value)
    self.task.file_name_spec = value
  end

  def self.task_hiera=(value)
    self.task.file_name_hiera = value
  end

  def self.task_facts=(value)
    self.task.file_name_facts = value
  end

  def self.task_spec
    self.task.file_name_spec
  end

  def self.task_hiera
    self.task.file_name_hiera
  end

  def self.task_facts
    self.task.file_name_facts
  end

  def self.task=(value)
    @task = value
  end

  def self.task
    return @task if @task
    @task = Noop::Task.new
  end

  def self.method_missing(method, *args)
    self.task.send method, *args
  end
end
