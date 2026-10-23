class BenchmarksController < ApplicationController
  # A distro lens: the plate with one distro's ticks lit, plus its machines.
  def show
    @distro = params[:distro]
    raise ActionController::RoutingError, "Unknown distro" unless DistroBenchmark.valid_slug?(@distro)

    @own = captures.select { |c| c.distro == @distro }
  end

  # The ledger: every run of every capture as table rows.
  def compare; end
end
