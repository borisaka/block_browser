module ApplicationHelper

  def hth(h); h.unpack("H*")[0]; end
  def htb(h); [h].pack("H*"); end

  def format_time time, short = false
    Time.at(time).utc.strftime("%Y-%m-%d %H:%M#{short ? '' : ':%S %Z'}")
  end

  def format_amount amount
    a, b = ("%.8f" % ((amount || 0) / 1e8)).split(".")
    a = number_with_delimiter a
    [a, b].join(".")
  end

  def format_script string
    string.size > 100 ? string.gsub(/\s+/, "\n") : string
  end

  def calculate_reward height
    ((50.0 / (2 ** (height / Bitcoin::REWARD_DROP.to_f).floor)) * 1e8).to_i
  end

  def address_link addr
    if addr
      link_to(addr, address_path(addr)).html_safe
    else
      "<span class='error'>Error decoding address</span>".html_safe
    end
  end

end
