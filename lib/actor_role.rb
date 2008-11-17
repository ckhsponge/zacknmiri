module ActorRole
  def actor_role_text(k)
    k = k.to_sym
    case k
      when :bubbles
        "splash around with Bubbles"
      when :zack
        "get some milk with Zack"
      else
        "do the unknown"
    end
  end
end
