# -*- encoding: utf-8 -*-
class NdlStatistic < ActiveRecord::Base
  has_many :ndl_stat_manifestations, :dependent => :destroy
  has_many :ndl_stat_accepts, :dependent => :destroy
  has_many :ndl_stat_checkouts, :dependent => :destroy
  has_many :ndl_stat_accesses, :dependent => :destroy
  attr_accessible :term_id
  
  term_ids = Term.select(:id).map(&:id)
  
  validates_presence_of :term_id
  validates_uniqueness_of :term_id
  validates_inclusion_of :term_id, :in => term_ids

  TYPE_LIST = [ "all_items", "removed", "removed_sum" ]
  REGION_LIST = [ "domestic", "foreign" ] 

  # 呼び出し用メソッド
  def self.calc_sum
    term = Term.current_term
    NdlStatistic.where(:term_id => term.id).destroy_all
    NdlStatistic.create!(:term_id => term.id).calc_all
  end

  def self.calc_sum_prev_year
    term = Term.previous_term
    NdlStatistic.where(:term_id => term.id).destroy_all
    NdlStatistic.create!(:term_id => term.id).calc_all 
  end

  # NDL 年報用集計処理
  def calc_all
    # validates term_id
    begin
      @prev_term_end = Term.where(:id => term_id).first.start_at.yesterday
      @curr_term_end = Term.where(:id => term_id).first.end_at
      @language_japanese_id = Language.find_by_name('Japanese').id
      @circulation_removed_id = CirculationStatus.find_by_name('Removed').id
      @checkout_types = CheckoutType.all
      @carrier_types = CarrierType.all
      @accept_types = AcceptType.all
    rescue Exception => e
      p "Failed: #{e}"
      logger.error "Failed: #{e}"
      return false
    end
    # calculate ndl statistics
    self.calc_manifestation_counts
    self.calc_accept_counts
    self.calc_checkout_counts
    self.calc_access_counts
  rescue Exception => e
    p "Failed to calculate ndl statistics: #{e}"
    logger.error "Failed to calculate ndl statistics: #{e}"
  end
  
  # 1. 所蔵
  def calc_manifestation_counts
    NdlStatistic.transaction do
      # 公開区分
      [ TRUE, FALSE].each do |pub_flg|
        TYPE_LIST.each do |type|
          # 製本済み資料を除く # 環境省以外は bookbinding_id ではなく bookbinder_id
          query = "bookbinding_id IS NULL OR items.bookbinder IS TRUE AND items.created_at <= ?"
          case type
          when "all_items", "public_items"
            query += " AND circulation_status_id != #{@circulation_removed_id}"
            query += " AND public_flg IS TRUE" unless pub_flg
          when "removed", "removed_sum"
            query += " AND circulation_status_id = #{@circulation_removed_id}"
            query += " AND removed_at between ? and ?" if type == "removed"
          end
          items_all = type == "removed" ? Item.joins(:manifestation).where(query, @curr_term_end, @prev_term_end, @curr_term_end):
                                          Item.joins(:manifestation).where(query, @curr_term_end)
        
          # 日本、外国
          REGION_LIST.each do |region|
            if region == "domestic"
              items = items_all.where("language_id = ?", @language_japanese_id)
            else
              items = items_all.where("language_id != ?", @language_japanese_id)
            end
            # 貸出区分/資料区分(環境省)
            @checkout_types.each do |checkout_type|
              # 資料形態
              @carrier_types.each do |carrier_type|
                count = items.where("checkout_type_id = ?", checkout_type.id).
                              where("carrier_type_id = ?", carrier_type.id).count
                # サブクラス生成
                n= ndl_stat_manifestations.new(
                  :stat_type => type,
	          :region => region,
                  :checkout_type_id => checkout_type.id,
                  :carrier_type_id => carrier_type.id,
                  :count => count)
                n.pub_flg = pub_flg
                n.save!
              end
            end
          end
	end
      end
    end
  rescue Exception => e
    p "Failed to manifestation counts: #{e}"
    logger.error "Failed to calculate manifestation counts: #{e}"
  end

  # 2. 受入
  def calc_accept_counts
    NdlStatistic.transaction do
      # 公開区分
      [ TRUE, FALSE].each do |pub_flg|
        items_all = Item.joins(:manifestation).
          where("bookbinding_id IS NULL OR items.bookbinder IS TRUE").  # 環境省以外は bookbinder_id
          where("items.created_at BETWEEN ? AND ?" ,@prev_term_end ,@curr_term_end)
        items_all = items_all.where("public_flg IS TRUE") unless pub_flg
        # 日本、外国
        [ "domestic", "foreign" ].each do |region|
          if region == "domestic"
            items = items_all.where("language_id = ?", @language_japanese_id)
          else
            items = items_all.where("language_id != ?", @language_japanese_id)
          end
          # 貸出区分/資料区分(環境省)
          @checkout_types.each do |checkout_type|
            # 資料形態
            @carrier_types.each do |carrier_type|
              # 受入区分
              @accept_types.each do |accept_type|
                count = items.where("checkout_type_id = ?", checkout_type.id).
                              where("carrier_type_id = ?", carrier_type.id).
                              where("accept_type_id = ?", accept_type.id).count
	        # サブクラス生成
                ndl_stat_accepts.create(
	          :region => region,
	          :checkout_type_id => checkout_type.id,
	          :carrier_type_id => carrier_type.id,
	          :accept_type_id => accept_type.id,
                  :pub_flg => pub_flg,
                  :count => count)
              end
            end
          end
	end
      end
    end
  rescue Exception => e
    p "Failed to accept counts: #{e}"
    logger.error "Failed to accept manifestation counts: #{e}"
  end

  # 3. 利用
  def calc_checkout_counts
    NdlStatistic.transaction do
      # p "ndl_statistics of checkout_counts"
      # 貸出区分
      @checkout_types.each do |checkout_type|
        # 資料形態
        @carrier_types.each do |carrier_type|
          checkouts = Checkout.joins(:item => :manifestation).
                               where("checkout_type_id = ?", checkout_type.id).
                               where("carrier_type_id = ?", carrier_type.id)
          # 貸出者数
          user = checkouts.where("checkouts.created_at between ? and ?",
                                  @prev_term_end, @curr_term_end).count
	  # 貸出資料数
          item = checkouts.where("checkouts.created_at between ? and ?",
                                  @prev_term_end, @curr_term_end).count
          ndl_stat_checkouts.create(
            :checkout_type_id => checkout_type.id,
            :carrier_type_id => carrier_type.id,
	    :users_count => user,
	    :items_count => item)
        end
      end
    end
  rescue Exception => e
    p "Failed to checkout counts: #{e}"
    logger.error "Failed to calculate checkout counts: #{e}"
  end

  # 4. アクセス件数
  def calc_access_counts
    NdlStatistic.transaction do 
      # 内部/外部
      [ TRUE, FALSE ].each do |internal|
        # アクセス画面
        AccessLog.group(:log_type).select(:log_type).map(&:log_type).each do |log_type|
          datas = AccessLog.where(:log_type => log_type, :internal => internal).
                            where("date between ? and ?", @prev_term_end, @curr_term_end)
          ndl_stat_accesses.create(
            :log_type => log_type,
            :internal => internal,
            :count => datas.sum(:value))
        end
      end
    end
  rescue Exception => e
    p "Failed to access counts: #{e}"
    logger.error "Failed to access counts: #{e}"
  end
private
  # excel 出力
  def self.get_ndl_report_excelx(ndl_statistic)
    # initialize
    out_dir = "#{Rails.root}/private/system/ndl_report_excelx" 
    excel_filepath = "#{out_dir}/ndlreport#{Time.now.strftime('%s')}#{rand(10)}.xlsx"
    FileUtils.mkdir_p(out_dir) unless FileTest.exist?(out_dir)

    logger.info "get_ndl_report_excelx filepath=#{excel_filepath}"
    
    @font_size = 10
    @height = @font_size * 1.5

    # prepare for header
    @checkout_types = CheckoutType.all
    @carrier_types = CarrierType.all
    @accept_types = AcceptType.all
    
    require 'axlsx'
    Axlsx::Package.new do |p|
      wb = p.workbook
      wb.styles do |s|
        title_style = s.add_style :font_name => Setting.manifestation_list_print_excelx.fontname,
	                          :alignment => { :vertical => :center },
				  :sz => @font_size+2, :b => true
        @header_style = s.add_style :font_name => Setting.manifestation_list_print_excelx.fontname,
	                           :alignment => { :vertical => :center },
                                   :border => Axlsx::STYLE_THIN_BORDER,
                                   :sz => @font_size, :b => true
         
        default_style = s.add_style :font_name => Setting.manifestation_list_print_excelx.fontname,
	                            :alignment => { :vertical => :center },
                                    :border => Axlsx::STYLE_THIN_BORDER,
				    :sz => @font_size
        # 所蔵統計
        # 公開区分
        last_row = 3+@carrier_types.size # 所蔵数出力の最終行(合計出力用)
        [ TRUE, FALSE ].each do |pub_flg|
          sheet_name = I18n.t("ndl_statistics.pub_flg.#{pub_flg.to_s}")
          wb.add_worksheet(:name => sheet_name) do |sheet|
            # (1) 所蔵
	    sheet.add_row ['(1) 図書'], :style => title_style, :height => @height*2
            checkout_region_header(sheet)

            sheet.column_info[0].width = 15
            sheet.column_info[1].width = 15
            TYPE_LIST.each do |type|
              next if pub_flg && type != 'all_items'
              @carrier_types.each do |carrier_type|
                row = [I18n.t("ndl_statistics.type.#{type}"), carrier_type.display_name.localize]
                @checkout_types.each do |checkout_type|
                  REGION_LIST.each do |region|
                    data = ndl_statistic.ndl_stat_manifestations.where(:stat_type => type, :carrier_type_id => carrier_type.id,
                                                                       :checkout_type_id => checkout_type.id, :region => region).first
                    row << data.count if data
                  end
                end
                sheet.add_row row, :style => default_style, :height => @height
              end
              # 合計の出力
              if type == 'all_items'
                columns = ('C'..'Z').to_a #TODO for columns after AA
                row = ['','合計']
                num = @checkout_types.size*2
                num.times do |i|
                  column = columns[i]
                  row << "=SUM(#{column}4:#{column}#{last_row})"
                end
                sheet.add_row row, :style => default_style, :height => @height
              end
            end
            sheet.add_row
            # (2) 受入
            sheet.add_row ['(2) 受入'], :style => title_style, :height => @height*2
            checkout_region_header(sheet)
            # 受入区分
            @accept_types.each do |accept_type|
              @carrier_types.each do |carrier_type|
                row = [accept_type.name, carrier_type.display_name.localize]
                sum = 0
                @checkout_types.each do |checkout_type|
                  REGION_LIST.each do |region|
                    data = ndl_statistic.ndl_stat_accepts.where(:accept_type_id => accept_type.id, :checkout_type_id => checkout_type.id,
                                                                :region => region, :carrier_type_id => carrier_type.id).first
                    row << data.count if data
                    sum += data.count
                  end
                end
                row << sum
                sheet.add_row row, :style => default_style, :height => @height
              end
            end
            # 合計の出力
            columns = ('C'..'Z').to_a
            @carrier_types.each_with_index do |carrier_type, index|
              row = ['合計',carrier_type.display_name.localize]
              num = @checkout_types.size*2+1
              num.times do |i|
                row_num = last_row+6+index
                column = columns[i]
                sum_columns = []
                @accept_types.size.times {sum_columns << "#{column}#{row_num}";row_num+=@carrier_types.size}
                row << "=SUM(#{sum_columns.join(',')})"
              end
                sheet.add_row row, :style => default_style, :height => @height
            end
          end
        end
        # 利用統計
        checkout_stat_types = ['items_count', 'users_count']
        wb.add_worksheet(:name => '利用統計') do |sheet|
          # (3) 利用
	  sheet.add_row ['(3)利用'], :style => title_style, :height => @height*2
          # 貸出冊数/貸出者数ヘッダ
          header = checkout_stat_types.inject(['']){|array,t| array += [I18n.t("ndl_statistics.checkout.#{t}"),'']}
          sheet.add_row header, :style => @header_style, :height => @height
          # 印刷物/それ以外ヘッダ
          header = checkout_stat_types.inject(['']){|array,t| array += [I18n.t("ndl_statistics.carrier_type.print"), I18n.t("ndl_statistics.carrier_type.other")]}
          sheet.add_row header, :style => @header_style, :height => @height
          @checkout_types.each do |checkout_type|
            row = [checkout_type.display_name.localize]
            checkout_stat_types.each do |s_type| # 貸出冊数/貸出者数
              ['print', 'other'].each do |c_type| # 印刷物/それ以外 
                datas = ndl_statistic.ndl_stat_checkouts.where(:checkout_type_id => checkout_type.id,
                                                               :carrier_type_id => CarrierType.try(c_type).collect(&:id))
                row << datas.sum(s_type)
              end 
            end
            sheet.add_row row, :style => default_style, :height => @height
          end      
          # 合計の出力
          columns = ('B'..'Z').to_a
          last_row = @checkout_types.size+3
          row = ['合計']
          4.times do |i|
            column = columns[i]
            row << "=SUM(#{column}4:#{column}#{last_row})"
          end
          sheet.add_row row, :style => default_style, :height => @height
        end
        # アクセス件数
        wb.add_worksheet(:name => 'アクセス件数') do |sheet|
          sheet.add_row ['(4)アクセス件数'], :style => title_style, :height => @height*2
          # 内部/外部
          [TRUE, FALSE].each do |internal|
          end
        end  
        p.serialize(excel_filepath)
      end
      return excel_filepath
    end
  rescue Exception => e
    p "Failed to create ndl report excelxt: #{e}"
    logger.error "Failed to create ndl report excelx: #{e}"
  end

  # 貸出区分・日本/外国区分ヘッダ
  def self.checkout_region_header(sheet)
    # 貸出区分ヘッダ
    header = @checkout_types.inject(['','']){|array,c| array += [c.display_name.localize, '']}
    sheet.add_row header, :style => @header_style, :height => @height
    # 日本、外国区分ヘッダ
    header = @checkout_types.inject(['','']){|array,c| array += ['日本','外国']}
    sheet.add_row header, :style => @header_style, :height => @height
  end
 
end
