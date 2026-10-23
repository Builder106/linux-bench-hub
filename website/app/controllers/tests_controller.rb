class TestsController < ApplicationController
  def show
    @test = BenchTest.find(params[:test])
    raise ActionController::RoutingError, "Unknown test" unless @test
  end
end
