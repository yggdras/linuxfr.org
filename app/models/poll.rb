# == Schema Information
# Schema version: 20090308230814
#
# Table name: polls
#
#  id         :integer(4)      not null, primary key
#  state      :string(255)     default("draft"), not null
#  title      :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class Poll < Content
  include AASM

  has_many :answers, :class_name => 'PollAnswer',
                     :dependent => :destroy,
                     :order => 'position'
  accepts_nested_attributes_for :answers, :allow_destroy => true,
      :reject_if => proc { |attrs| attrs['answer'].blank? }

  validates_presence_of :title, :message => "La question est obligatoire"

### SEO ###

  has_friendly_id :title, :use_slug => true

### Workflow ###

  aasm_column :state
  aasm_initial_state :draft

  aasm_state :draft
  aasm_state :published
  aasm_state :archived
  aasm_state :refused
  aasm_state :deleted

  aasm_event :accept  do transitions :from => [:draft],     :to => :published, :on_transition => :publish end
  aasm_event :refuse  do transitions :from => [:draft],     :to => :refused  end
  aasm_event :archive do transitions :from => [:published], :to => :archived end
  aasm_event :delete  do transitions :from => [:published], :to => :deleted  end

  # There can be only one current poll,
  # so we archive other polls when publish a new one.
  def publish
    Poll.published.each do |poll|
      poll.archive unless poll.id == self.id
    end
  end

  def self.current
    published.first
  end

### ACL ###

  def readable_by?(user)
    %w(published archived).include?(state) || (user && user.amr?)
  end

  def editable_by?(user)
    user && user.amr?
  end

  def deletable_by?(user)
    user && user.admin?
  end

  def acceptable_by?(user)
    user && user.amr?
  end

  def refusable_by?(user)
    user && user.amr?
  end

  def answerable_by?(ip)
    published? # FIXME only one vote per IP and per day
  end

### Votes ###

  # Number of votes + 1 to avoid division by 0
  def total_votes
    answers.sum(:votes)
  end

end