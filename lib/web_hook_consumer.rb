class WebHookConsumer
  
  def sync
    loop do
      web_hook = WebHook.where(sync_state: "TODO").find_one_and_update({"$set" => {sync_state: "PROCESSING"}, "$currentDate" => {sync_ts: true}})
      break if web_hook.nil?
      consume web_hook
      web_hook.set(sync_state: "DONE", sync_ts: DateTime.now)
    end
  end 

  def consume web_hook
    id = web_hook.issue["id"]
    number = web_hook.issue["number"]
    title = web_hook.issue["title"]
    html_url = web_hook.issue["html_url"]
    labels = web_hook.issue["labels"].map {|label| label["name"]}
    author = web_hook.sender["login"]
    state = web_hook.issue["state"]
    body = web_hook.issue["body"]
    milestone_id = web_hook.issue["milestone"].present? ? web_hook.issue["milestone"]["id"] : nil

    self.manage(id, number, title, html_url, labels, author, state, body, milestone_id)
  end

  def self.manage id, number, title, html_url, labels, author, state, body, milestone_id
    epic = Milestone.where(id: milestone_id).first
    if milestone_id.present?
      if epic.nil?
        epic = Milestone.create_milestone(web_hook.issue["milestone"])
      end
    end

    ticket = Ticket.insert_or_update id, number, title, html_url, labels, author, state, body, milestone_id
    ticket.create_story
    ticket.set_epic epic
    ticket.sync
  end
end