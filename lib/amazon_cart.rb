require 'rubygems'
require 'osx/cocoa'
require 'yaml'
require 'fileutils'

class AmazonCart < OSX::NSObject
  include OSX

  @@instance = nil

  attr_reader :items
  attr_accessor :active_items, :saved_items
  ib_outlet :active_items, :saved_items
  ib_outlet :app

  kvc_accessor :active_items_model, :saved_items_model
  
  LOCAL_CACHE_PATH = File.expand_path("~/Library/Application Support/AmazonOrganizer/LocalCache.yaml")

  def awakeFromNib()
    @amazon = nil
    @active_items_model = NSMutableArray.alloc.init
    @saved_items_model = NSMutableArray.alloc.init
    @items = {}

    @lists = {:active => @active_items, :saved => @saved_items}
    
    if(!@not_restore)
      Thread.start do
        restore_from_save_image(load_local_cache)
      end
    end
  end

  # initialization code called from Unit Test
  def test_initialize
    @not_restore = true
    @active_items = NSArrayController.alloc
    @saved_items = NSArrayController.alloc
    awakeFromNib
    @active_items.initWithContent(@active_items_model)
    @saved_items.initWithContent(@saved_items_model)
  end

  def amazon
    # Can't move this to awakeFromNib because App may not available when this class's awakeFromNib is called
    # (AppController#awakeFromNib sets it.)
    @amazon = AmazonOrganizer::Amazon.new(self, AccountInfo.new, App.log) unless @amazon
    @amazon
  end

  def reload
    Thread.new do 
      not_found = amazon.fetch(@items.keys)
      not_found.each do |asin|
        delete_item(@items[asin][1])
      end
    end
  end

  def submit
    amazon.update(get_state_to_save)
  end

  def add(item, state)
    item_model = nil

    if @items.has_key?(item.asin)
      item_model = @items[item.asin][1]
    else
      item_model = ItemModel.new
      item_model.asin = item.asin
    end
    move_item(state, item_model)
    item_model.copy_item(item)
  end

  def get_state_to_save
    Hash[*items.collect { |asin, pair| [asin, pair[0]] }.flatten]
  end

  def add_item(to, item)
    move_item(to, item)
  end

  def delete_item(item)
    move_item(nil, item)
  end

  def move_item(to, item)
    raise NameError, "wrong list name #{to}" unless (to.nil? or @lists.has_key?(to))
    if to.nil? and items[item.asin].nil?
      raise ArgumentError, "#{item.asin} is not stored"
    end

    from = (items[item.asin] || [])[0]
    return if from == to
    @lists[to].addObject(item) unless to.nil?
    @lists[from].removeObject(item) unless from.nil?
    if to.nil?
      items.delete(item.asin)
    else
      items[item.asin] = [to, item]
    end
  end

  def get_items_model_save_image(model_list)
    model_list.to_a.collect{|item| item.get_save_image}
  end

  def get_save_image
    result = {}
    result[:active_items] = get_items_model_save_image(@active_items_model)
    result[:saved_items] = get_items_model_save_image(@saved_items_model)
    result
  end

  def save_local_cache
    puts "world!"
    FileUtils.mkdir_p(File.dirname(LOCAL_CACHE_PATH))
    File.open(LOCAL_CACHE_PATH, "w") do |file|
      YAML.dump(get_save_image, file)
    end
  end

  def restore_items_from_save_image(list, hash_list)
    hash_list.each do |item|
      item_model = ItemModel.new
      item_model.instance_eval{ @asin = item[:asin] }
      move_item(list, item_model)
      item_model.restore_from_save_image(item)
    end
  end

  def restore_from_save_image(save_image)
    return if save_image.nil?
    restore_items_from_save_image(:active, save_image[:active_items])
    restore_items_from_save_image(:saved, save_image[:saved_items])
  end

  def load_local_cache
    return nil unless File.exists?(LOCAL_CACHE_PATH)
    yaml = File.read(LOCAL_CACHE_PATH)
    YAML.load(yaml)
  end

end

