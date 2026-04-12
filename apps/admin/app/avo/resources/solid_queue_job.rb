# frozen_string_literal: true

class Avo::Resources::SolidQueueJob < Avo::BaseResource
  self.title = :id
  self.model_class = ::SolidQueue::Job

  def fields
    field :id, as: :id
    field :queue_name, as: :text
    field :class_name, as: :text
    field :arguments, as: :textarea
    field :priority, as: :number
    field :active_job_id, as: :text
    field :scheduled_at, as: :date_time
    field :finished_at, as: :date_time
    field :concurrency_key, as: :text
    field :created_at, as: :date_time
    field :updated_at, as: :date_time
  end
end
