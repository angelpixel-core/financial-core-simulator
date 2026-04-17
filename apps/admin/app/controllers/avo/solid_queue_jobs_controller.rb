# This controller has been generated to enable Rails' resource routes.
# More information on https://docs.avohq.io/3.0/controllers.html
class Avo::SolidQueueJobsController < Avo::ResourcesController
  before_action :ensure_solid_queue_table!, only: %i[index show]

  private

  def ensure_solid_queue_table!
    return if SolidQueue::Job.table_exists?

    redirect_to avo.resources_runs_path, alert: 'Solid Queue table is not available in this environment.'
  end
end
