class MessagesController < ApplicationController
  def index
  end

  def create
    id = params[:id]
    message = params[:message]
    WebsocketRails.users[id].send_message 'receive', message
  end
end
