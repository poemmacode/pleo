# Public page linked from the crawler's User-Agent, so site owners can see what the bot does.
class BotController < ApplicationController
  allow_unauthenticated_access

  def show
  end
end
