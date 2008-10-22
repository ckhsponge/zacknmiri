module ActorRole
  def actor_role_text(k)
    k = k.to_sym
    case k
      when :bubbles
        "do something naughty with Bubbles"
      when :zack
        "deliver the milk with Zack"
      else
        "do the unknown"
    end
  end
end
