module UserSerializer
  def self.call(user)
    { id: user.id, email: user.email }
  end
end
