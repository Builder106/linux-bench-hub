class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :captures

  private

  # Every page draws from the same six latest captures (three distros, two
  # architectures), so the combs, the ledger and the footer always agree.
  def captures
    @captures ||= Capture.all
  end
end
