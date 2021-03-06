# frozen_string_literal: true

# Rendering push activities can be tricky, since tags can come on go, and with
# them, dangling repositories that used to contain them. Because of this, this
# helper renders the proper HTML for push activities, while being safe at it.
module RepositoriesHelper
  include ActivitiesHelper

  def render_repository_information(repository)
    content_tag(:ul) do
      concat content_tag(:li, "You can push images") if can_push?(repository.namespace)
      concat content_tag(:li, "You can pull images") if can_pull?(repository.namespace)

      if owner?(repository.namespace)
        concat content_tag(:li, "You are an owner of this repository")
      elsif contributor?(repository.namespace)
        concat content_tag(:li, "You are a contributor in this repository")
      elsif viewer?(repository.namespace)
        concat content_tag(:li, "You are a viewer in this repository")
      end
    end
  end

  # Renders a push activity, that is, a repository/tag has been pushed.
  def render_push_activity(activity)
    render_repo_activity(activity, "pushed")
  end

  # Renders a delete activity, that is, a repository/tag has been deleted.
  def render_delete_activity(activity)
    render_repo_activity(activity, "deleted")
  end

  # Returns true if the user can remove the given repository.
  def can_destroy_repository?(repository)
    RepositoryPolicy.new(current_user, repository).destroy?
  end

  # Returns if any security module is enabled
  def security_vulns_enabled?
    ::Portus::Security.enabled?
  end

  # Returns true if any vulnerability is found
  # Or false otherwise
  def vulnerable?(vulnerabilities)
    return if vulnerabilities.blank?
    !vulnerabilities.reject { |_, vulns| vulns.empty? }.empty?
  end

  protected

  # General method for rendering an activity regarding repositories.
  def render_repo_activity(activity, action)
    owner = content_tag(:strong, "#{activity_owner(activity)} #{action} ")

    namespace = render_namespace(activity)
    namespace += " / " unless namespace.empty?

    owner + namespace + render_repository(activity)
  end

  # Renders the namespace part of the activity in a safe manner. If the
  # namespace still exists, it will be taken as the target for the created
  # link. Otherwise, it will try to fetch the name of the namespace and put it
  # inside of a <span> element. If this is not possible, then an empty string
  # will be returned.
  def render_namespace(activity)
    tr = activity.trackable

    if tr.nil? || tr.is_a?(Namespace)
      if activity.parameters[:namespace_name].nil?
        ""
      else
        namespace = Namespace.find_by(id: activity.parameters[:namespace_id])
        tag_or_link(namespace, activity.parameters[:namespace_name])
      end
    else
      link_to tr.namespace.clean_name, tr.namespace
    end
  end

  # Returns a link if the namespace is not nil, otherwise just a tag with the
  # given name.
  def tag_or_link(namespace, name)
    namespace.nil? ? content_tag(:span, name) : link_to(name, namespace)
  end

  # Renders the repository part of the activity in a safe manner.
  def render_repository(activity)
    repo, link, tag = get_repo_link_tag(activity)

    if link.nil?
      content_tag(:span, "#{repo}#{tag}")
    else
      link_to "#{repo}#{tag}", link
    end
  end

  # Helper for the render_repository method.
  def get_repo_link_tag(activity)
    tr = activity.trackable

    if tr.nil?
      if repo_name(activity).nil?
        ["a repository", nil, ""]
      else
        repo = repo_name(activity)
        ns   = Namespace.find_by(id: activity.parameters[:namespace_id])
        link = ns.nil? ? nil : namespace_path(ns.id)
        [repo, link, tag_part(activity)]
      end
    else
      name, l = name_and_link(tr, activity)
      [name, l, tag_part(activity)]
    end
  end

  # Renders the tag for the given activity. It will return an empty string if
  # the tag could not be found, otherwise it will return the tag with a ":"
  # prefixed to it.
  def tag_part(activity)
    if activity.recipient.nil?
      if activity.parameters[:tag_name].nil?
        ""
      else
        ":#{activity.parameters[:tag_name]}"
      end
    else
      ":#{activity.recipient.name}"
    end
  end

  # Fetch the name of the repo from the given activity.
  def repo_name(activity)
    activity.parameters[:repo_name] || activity.parameters[:repository_name]
  end

  # Returns the name and the link to the given tr depending on whether it's a
  # Namespace or not.
  def name_and_link(tr, activity)
    tr.is_a?(Namespace) ? [repo_name(activity), nil] : [tr.name, tr]
  end

  # Returns the prefix tags path. This url doesn't exist in routes because it's not needed.
  # This is only useful for the UI.
  def tags_path
    "#{Rails.application.config.relative_url_root}/tags"
  end
end
