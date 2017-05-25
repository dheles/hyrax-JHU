# Generated via
#  `rails generate hyrax:work Work`

# attribute mapping from dspace_packager.rake:
## "dc.title" => "title",
## "dc.contributor.author" => "creator",
## "dc.date.issued" => "date_issued",
# "dc.identifier.uri" => "handle",
# "dc.description.abstract" => "abstract",
# "dc.description.provenance" => "provenance",
# "dc.description.sponsorship" => "sponsor",
## "dc.language.iso" => "language",
## "dc.subject" => "subject",
# "dc.type" => "resource_type",
# "dc.relation.ispartofseries" => "part_of"
## "dc.date.available" => "date_uploaded",
# "dc.date.accessioned" => "date_accessioned",

class Work < ActiveFedora::Base
  include ::Hyrax::WorkBehavior
  include ::Hyrax::BasicMetadata
  # Change this to restrict which works can be added as a child.
  # self.valid_child_concerns = []
  validates :title, presence: { message: 'Your work must have a title.' }
  
  self.human_readable_type = 'Work'

  property :handle, predicate: ::RDF::Vocab::PREMIS.ContentLocation do |index|
    index.as :stored_searchable, :facetable
end

  property :abstract, predicate: ::RDF::Vocab::DC.abstract do |index|
    index.as :stored_searchable, :facetable
  end

  property :provenance, predicate: ::RDF::Vocab::DC.provenance

  property :sponsor, predicate: ::RDF::Vocab::MARCRelators.spn do |index|
    index.as :stored_searchable, :facetable
  end

  property :resource_type, predicate: ::RDF::Vocab::DC11.type do |index|
      index.as :stored_searchable, :facetable
  end

  property :is_part_of, predicate: ::RDF::Vocab::DC.isPartOf do |index|
    index.as :stored_searchable, :facetable
  end

  property :date_accessioned, predicate: ::RDF::Vocab::DC.date, multiple: false
end
