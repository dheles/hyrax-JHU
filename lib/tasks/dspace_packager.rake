# Author: Aaron Collier, CalState
# Adapted for JHU by Drew Heles

# Steps to use this:
# 1 - Export DSpace data in AIP format
# ---- [dspace bin]/dspace packager -d -a -e [email address] -i [handle of comm/coll/item] -t AIP [full path to export file name in .zip format]
# ---- this will include all sub items and collections in ITEM-HANDLE.zip format - move all files to server for import
# 2 - in the directory with the above zip files, add a "complete" directory (this should be added to the code, just hasn't been done yet)
# 3 - run the rake from your hydra project root as: rake packager:aip["path/to/top_level_zip","admin@somehere.edu"] (where admin@ is your admin email address)

# a few things to keep in mind, the below "attributes" has is largely dependant on our data mapping, so if those dublin core fieds show up
# you'll need to comment them out to not include them, or add them to your model. the attribute is based on the dc key.

# There's a bit here that I'm not doing anything with anymore or yet, like capturing the community heirarchy to include in metadata. should be easy to reistablish that

# Sometimes a dspace created zip file will cause an error. Remove or move that file then move your NON item zip files back from "complete to the root folder and rerun to catch up from where it failed.

require 'rubygems'
require 'zip'

@attributes = {
  "dc.title" => "title",
  "dc.contributor.author" => "creator",
  "dc.date.issued" => "date_created",
  "dc.identifier.uri" => "handle",
  "dc.description.abstract" => "abstract",
  "dc.description.provenance" => "provenance",
  "dc.description.sponsorship" => "sponsor",
  "dc.language.iso" => "language",
  "dc.subject" => "subject",
  "dc.type" => "resource_type",
  "dc.relation.ispartofseries" => "is_part_of"
}

@singulars = {
  "dc.date.available" => "date_uploaded",
  "dc.date.accessioned" => "date_accessioned",
  "dc.date.embargountil" => "embargo_release_date", # Thesis
}

# This is a variable to use during XML parse testing to avoid submitting new items
@debugging = FALSE

namespace :packager do

  task :aip, [:file, :user_id] =>  [:environment] do |t, args|
    puts "loading task import"

    @coverage = "" # for holding the current DSpace COMMUNITY name
    @sponsorship = "" # for holding the current DSpace CoLLECTIOn name

    @unmappedFields = File.open("/tmp/unmappedFields.txt", "w")

    @source_file = args[:file] or raise "No source input file provided."
    #@current_user = User.find_by_user_key(args[:user_id])

    @defaultDepositor = User.find_by_user_key(args[:user_id]) # THIS MAY BE UNNECESSARY

    puts "Building Import Package from AIP Export file: " + @source_file

    abort("Exiting packager: input file [" + @source_file + "] not found.") unless File.exists?(@source_file)

    @input_dir = File.dirname(@source_file)
    @output_dir = File.join(@input_dir, "unpacked") ## File.basename(@source_file,".zip"))
    Dir.mkdir @output_dir unless Dir.exist?(@output_dir)

    unzip_package(File.basename(@source_file))

    # puts @uncapturedFields
    @unmappedFields.close

  end
end

def unzip_package(zip_file,parentColl = nil)

  zpath = File.join(@input_dir, zip_file)

  if File.exist?(zpath)
    file_dir = File.join(@output_dir, File.basename(zpath, ".zip"))
    @bitstream_dir = file_dir
    Dir.mkdir file_dir unless Dir.exist?(file_dir)
    Zip::File.open(zpath) do |zipfile|
      zipfile.each do |f|
        fpath = File.join(file_dir, f.name)
        zipfile.extract(f,fpath) unless File.exist?(fpath)
      end
    end
    if File.exist?(File.join(file_dir, "mets.xml"))
      File.rename(zpath,@input_dir + "/complete/" + zip_file)
      return process_mets(File.join(file_dir,"mets.xml"),parentColl)
    else
      puts "No METS data found in package."
    end
  end

end

def process_mets (mets_file,parentColl = nil)

  children = Array.new
  files = Array.new
  uploadedFiles = Array.new
  depositor = ""
  type = ""
  params = Hash.new {|h,k| h[k]=[]}

  if File.exist?(mets_file)
    # xml_data = Nokogiri::XML.Reader(open(mets_file))
    dom = Nokogiri::XML(File.open(mets_file))

    current_type = dom.root.attr("TYPE")
    current_type.slice!("DSpace ")
    # puts "TYPE = " + current_type

    # puts dom.class
    # puts dom.xpath("//mets").attr("TYPE")

    data = dom.xpath("//dim:dim[@dspaceType='"+current_type+"']/dim:field", 'dim' => 'http://www.dspace.org/xmlns/dspace/dim')

    data.each do |element|
     field = element.attr('mdschema') + "." + element.attr('element')
     field = field + "." + element.attr('qualifier') unless element.attr('qualifier').nil?
     # puts field + " ==> " + element.inner_html

     # Due to duplication and ambiguity of output fields from DSpace
     # we need to do some very simplistic field validation and remapping
     case field
     when "dc.creator"
       if element.inner_html.match(/@/)
         # puts "Looking for User: " + element.inner_html
         depositor = getUser(element.inner_html) unless @debugging
         # depositor = @defaultDepositor
         # puts depositor
       end
     when "dc.relation.ispartofseries"
       params[@attributes[field]] << element.inner_html.tr(' ', '%20') if @attributes.has_key? field
       params[@singulars[field]] = element.inner_html.tr(' ', '%20') if @singulars.has_key? field
     else
       params[@attributes[field]] << element.inner_html if @attributes.has_key? field
       params[@singulars[field]] = element.inner_html if @singulars.has_key? field
     end
     # @uncapturedFields[field] += 1 unless (@attributes.has_key? field || @singulars.has_key? field)
     @unmappedFields.write(field) unless @attributes.has_key? field
    end

    case dom.root.attr("TYPE")
    when "DSpace COMMUNITY"
      type = "admin_set"
      puts params
      @coverage = params["title"][0]
      puts "*** COMMUNITY ["+@coverage+"] ***"
      # puts params
    when "DSpace COLLECTION"
      type = "admin_set"
      @sponsorship = params["title"][0]
      puts "***** COLLECTION ["+@sponsorship+"] *****"
      # puts params
    when "DSpace ITEM"
      puts "******* ITEM ["+params["handle"][0]+"] *******"
      type = "work"
      # params["sponsorship"] << @sponsorship
      # params["coverage"] << @coverage
    end

    # if type == 'collection'
    if type == 'admin_set'
      structData = dom.xpath('//mets:mptr', 'mets' => 'http://www.loc.gov/METS/')
      structData.each do |fileData|
        case fileData.attr('LOCTYPE')
        when "URL"
          unzip_package(fileData.attr('xlink:href'))
          # puts coverage unless coverage.nil?
          # puts sponsorship unless sponsorship.nil?
        end
      end
    elsif type == 'work'
      # item = createItem(params,parentColl)

      fileMd5List = dom.xpath("//premis:object", 'premis' => 'http://www.loc.gov/standards/premis')
      fileMd5List.each do |fptr|
        fileChecksum = fptr.at_xpath("premis:objectCharacteristics/premis:fixity/premis:messageDigest", 'premis' => 'http://www.loc.gov/standards/premis').inner_html
        originalFileName = fptr.at_xpath("premis:originalName", 'premis' => 'http://www.loc.gov/standards/premis').inner_html
        # newFileName = dom.at_xpath("//mets:fileGrp[@USE='THUMBNAIL']/mets:file[@CHECKSUM='"+fileChecksum+"']/mets:FLocat/@xlink:href", 'mets' => 'http://www.loc.gov/METS/', 'xlink' => 'http://www.w3.org/1999/xlink').inner_html
        # puts newFileName

        ########################################################################################################################
        # This block seems incredibly messy and should be cleaned up or moved into some kind of method
        newFile = dom.at_xpath("//mets:file[@CHECKSUM='"+fileChecksum+"']/mets:FLocat", 'mets' => 'http://www.loc.gov/METS/')
        thumbnailId = nil
        case newFile.parent.parent.attr('USE') # grabbing parent.parent seems off, but it works.
        when "THUMBNAIL"
          newFileName = newFile.attr('xlink:href')
          puts newFileName + " -> " + originalFileName
          File.rename(@bitstream_dir + "/" + newFileName, @bitstream_dir + "/" + originalFileName)
          file = File.open(@bitstream_dir + "/" + originalFileName)

          sufiaFile = Hyrax::UploadedFile.create(file: file)
          sufiaFile.save
          # thumbnailId = sufiaFile.id

          uploadedFiles.push(sufiaFile)
          file.close
          ## params["thumbnail_id"] << sufiaFile.id
        when "TEXT"
        when "ORIGINAL"
          newFileName = newFile.attr('xlink:href')
          puts newFileName + " -> " + originalFileName
          File.rename(@bitstream_dir + "/" + newFileName, @bitstream_dir + "/" + originalFileName)
          # tried adding options to avoid error (on some files):
          # Encoding::UndefinedConversionError: "\xCC" from ASCII-8BIT to UTF-8
          # http://ruby-doc.org/core-2.3.3/IO.html#method-c-new-label-IO+Open+Mode
          # tried:
          # 'b' not valid
          # 'rb' doesn't work
          # 'ab' doesn't work
          # 'wb' works by truncating the file to zero-length
          # 'w+b' works by truncating the file to zero-length
          # 'r+b' doesn't work
          # 'a+b' doesn't work
          puts "modified mode test: " + originalFileName
          file = File.open(@bitstream_dir + "/" + originalFileName) #, 'w+b')
          sufiaFile = Hyrax::UploadedFile.create(file: file)
          sufiaFile.save
          uploadedFiles.push(sufiaFile)
          file.close
        when "LICENSE"
          # Temp commented to deal with PDFs
          # newFileName = newFile.attr('xlink:href')
          # puts "license text: " + @bitstream_dir + "/" + newFileName
          # file = File.open(@bitstream_dir + "/" + newFileName, "rb")
          # params["rights_statement"] << file.read
          # file.close
        end
        # puts newFile.class
        # puts newFile.attr('xlink:href')
        # puts newFile.parent.parent.attr('USE')
        # File.rename(@bitstream_dir + "/" + newFileName, @bitstream_dir + "/" + originalFileName)
        # file = File.open(@bitstream_dir + "/" + originalFileName)
        # uploadedFiles.push(Sufia::UploadedFile.create(file: file))
        ########################################################################################################################

        # sleep(10) # Sleeping 10 seconds while the file upload completes for large files...

      end

      puts "-------- UpLoaded Files ----------"
      puts uploadedFiles
      puts "----------------------------------"

      puts "** Creating Item..."
      item = createItem(params,depositor) unless @debugging
      puts "** Attaching Files..."
      workFiles = AttachFilesToWorkJob.perform_now(item,uploadedFiles) unless @debugging
      # workFiles.save
      # puts workFiles
      # item.thumbnail_id = thumbnailId unless thumbnailId.nil?
      puts "Item id = " + item.id
      # item.save

      return item

    end
  end
end

def createCollection (params, parent = nil)
  coll = AdminSet.new(params)
#  coll = Collection.new(id: ActiveFedora::Noid::Service.new.mint)
#  params["visibility"] = "open"
#  coll.update(params)
#  coll.apply_depositor_metadata(@current_user.user_key)
  coll.save
#  return coll
end


def createItem (params, depositor, parent = nil)
  if depositor == ''
    depositor = @defaultDepositor
  end

  # item = Thesis.new(id: ActiveFedora::Noid::Service.new.mint)
  item = Work.new(id: ActiveFedora::Noid::Service.new.mint)
  if params.key?("embargo_release_date")
    # params["visibility"] = "embargo"
    params["visibility_after_embargo"] = "open"
    params["visibility_during_embargo"] = "authenticated"
  else
    params["visibility"] = "open"
  end
  item.update(params)
  item.apply_depositor_metadata(depositor.user_key)
  item.save
  return item
end

def getUser(email)
  user = User.find_by_user_key(email)
  if user.nil?
    pw = (0...8).map { (65 + rand(52)).chr }.join
    puts "Created user " + email + " with password " + pw
    user = User.new(email: email, password: pw)
    user.save
  end
  # puts "returning user: " + user.email
  return user
end
