module ApplicationHelper
  # First validation message for an attribute, rendered next to its field.
  def field_error(record, attribute)
    message = record&.errors&.full_messages_for(attribute)&.first
    tag.span(message, class: "error", role: "alert") if message
  end
end
