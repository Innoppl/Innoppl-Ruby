################################################################################
##File Name -  user_controller.rb  - Model File
##Created by - Vimal Raj K 
##Created on - 10/04/2011
##Last Edited by - Chandramouli 
##Last Edited for - Inclusion of FB Connect
##Last Edited - 08/09/2011
##Purpose - The file is used for User Management registration ,edit profile etc.,
##################################################################################

class UsersController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :require_customer_role, :except => [:new, :create]
  require 'distance_calculator'
  
  def new
       logger.debug("IN NEW USER")
    @user = User.new
    @customer = Customer.new   
      session[:registration] = true
       logger.debug("END NEW USER")
  end
  
  def create
      logger.debug("IN CREATE USER")
      @user = User.new
    @user.attributes = params[:user]
    @user.role_id = Role.where("name = ?", 'user').first.id
    
      # if they came to us through facebook connect, let's associate their facebook info with the account
    if !session[:facebook_uid].blank?
        @user.facebook_uid = session[:facebook_uid]
        @user.facebook_access_token = session[:access_token] unless session[:access_token].blank?
    end
      
    @customer = Customer.new
    @customer.attributes = params[:customer]
    
    if !session[:dob_year].blank?
       @customer.dob = session[:dob_year] 
    else
        @customer.dob = "1920-01-01"
    end 
      
    @customer.household_income = @customer.household_income.to_i == 0? nil : @customer.household_income
    @customer.avatar = ProfileImage.new(params[:profile_image]) unless params[:profile_image].blank?
    @customer.avatar.attachable = @customer unless params[:profile_image].blank?
    @customer.gender = nil if @customer.gender != ("Male" || "Female")
    @error_list = ""
    @customer.valid?
    
     
    @user.errors.each_pair {|field, errors| errors.each {|error| @error_list = @error_list + "<li>#{field.to_s.capitalize.gsub(/_/," ")} " "#{error}</li>" }} unless @user.valid?    
    @customer.errors.each_pair {|field, errors| p field; p errors;errors.each {|error| @error_list = @error_list + "<li>#{field.to_s.capitalize.gsub(/_/," ")} " "#{error}</li>" }} unless @customer.valid?
    # TODO - Need to Change to provide proper validation message when image is invalid and size is greater that 200KB
    #    @customer.avatar.errors.each_pair {|field, errors| errors.each {|error| @error_list = @error_list + "<li>#{field.to_s.capitalize.gsub(/_/," ")} " "#{error}</li>" }} if !@customer.avatar.blank? && !@customer.avatar.valid?    
    @error_list = @error_list + "<li>Avatar Invalid</li>" if !@customer.avatar.blank? && !@customer.avatar.valid?
    # TODO - CAPTCHA IS COMMENTED AS FRONTNEED TO BE CHANGED.
    #    @error_list = @error_list + "<li>The captcha does not match!</li>" unless (params[:format]=="xml" || verify_recaptcha) 
    
      respond_to do |wants|
        logger.info("ABOUT TO CHECK IF THERE WERE ERRORS ON USER CREATE")
          logger.info(@error_list)
        if @error_list.blank?
                
            @user.signup!(params)  
            
                @customer.user_id = @user.id
            @customer.save
            # To make the user and the user who invited (if any), friends
            unless session[:invite_uid].blank?
                friend = Friend.new(:user_id => session[:invite_uid], :user_id_target => @user.id, :message => "")
                friend.save
                session[:invite_uid] = nil
            end
            # will be activate be default
            # @user.mail_activation_instructions!
       
            flash[:notice] = t("account_created_successfully")
            # wants.html{redirect_to new_user_session_path}        
            wants.xml{render $COMMON_RESPONSE,:locals=>{:status=>SUCCESS,:partial=>'shared/customer_profile',:error_fields=>NO_ERROR,:data=>{:user=>@user.reload}}}        
            wants.js
            UserSession.create(@user, true) 

        else
            flash[:error] = "Hang on a sec, we need your help below."

            wants.js
            wants.xml{render $COMMON_RESPONSE,:locals=>{:status=>FAILURE,:error_fields=>@customer.errors.to_hash.merge(@user.errors.to_hash)}}        
        end
      end
  end
  
  def filter_settings
    @categories = (params[:format] == "xml" && !params[:category_id].blank?) ?  (Category.find(params[:category_id]).children rescue nil) : Category.roots
    @category_ids = current_user.customer.category_ids
    respond_to do |format|
      format.xml {
        if @categories.blank?
          render $COMMON_RESPONSE, :locals => {:status => FAILURE, :partial => '', :error_fields => {:category => "Invalid category id"}}
        else  
          render $COMMON_RESPONSE, :locals => {:status => SUCCESS, :partial => 'users/filter_settings',:data =>{:categories => @categories, :selected_category_ids => @category_ids, :is_main_category => params[:category_id].blank?}, :error_fields => NO_ERROR}
        end
      }
      format.html
    end
  end
  
  def find_friends
    @errors = params[:errors] if params[:errors] 
    @oauth_url = MiniFB.oauth_url(FB_APP_ID, HOST, :scope => FACEBOOK_PERMISSIONS.join(","))
    #    @my_friends = GetFacebookFriends.friends_list(params, current_user) unless params[:code].blank?
  end
  
  def alists
    @alists = current_user.customer.venues
  end
  
  def venue_search_result
    page = {}
    page["no"] = params[:page] = params[:page].to_i > 0 ? params[:page].to_i : 1 unless params[:page].to_i==-1
    page["per_page"] = params[:format]=="xml" ? IPHONE_PER_PAGE : REG_ALIST_PER_PAGE
    params[:search][:value] = params[:search][:value].gsub("%5B%5D","") unless params[:format]=="xml"
    browse_type = params[:search].blank? ? [] : (CGI::parse params[:search][:value])
    result = Venue.venue_search_result(current_user, browse_type, params[:venue][:keywords], "", page, false, "", "", "", "", "1", params[:version], params[:device_type], params[:format])
    venues = result[:search_result].blank? ? [] : result[:search_result]
    total_count = result[:pagination_details]
    venues.each do |venue|
	     @deals = venue.get_all_valid_deals(current_user.customer.category_ids)
		      @deals.each do |deal|
			   deal.update_attributes(:click_count => (deal.click_count + 1))
			   deal.save
		      end 
    end  
    #    @current_user_alist_ids = current_user.customer.venue_ids
    respond_to do |format|
      format.js { 
        render :update do |part|
          venue_list = venues[0..((!(params[:page].to_i == -1) && venues.size > REG_ALIST_PER_PAGE) ? venues.size-2 : venues.size)]
          venue_list_html = escape_javascript(render :partial => "shared/venue_list_with_add",
                :locals => {:venues => venue_list})
          part << "$('#venue-list').html('#{venue_list_html}')"
          venue_list.size > 0 ? part << "$('#add-all-to-alist').css('display', 'block')" : part << "$('#add-all-to-alist').css('display', 'none')"  
          part << "$('#venue_ids').val('#{venue_list.collect(&:id).join(',')}')"
          part << "$('#venue-detail').html('')"
          part << "$('#busy-indicator').hide()"
          unless params[:page].to_i==-1
            venue_pagination_html = escape_javascript(render :partial => "users/alist_pagination",
                  :locals => {:venues => venues, :total_count => total_count, :page => page["no"].to_i, :item_count => venues.size, :limit => REG_ALIST_PER_PAGE }) unless venues.blank?
            part << "$('#venueSearchPagination').html('#{venue_pagination_html}')"
          else
            part << "$('#venueSearchPagination').html('')"
          end
          # part << "setTimeout('render_rounded_corners_image()', 1000);"
        end
      }
    end
  end
  
  
  def add_all_venues
    #TODO - WHEN POST REQUEST IS MORE IDS, APP CRASH. NEED TO SEND IDS IN BODY.
    params[:venue_ids] = params[:venue_ids].split(',') if params[:format] != 'xml' 
    venue_lists = current_user.customer.venue_ids << params[:venue_ids]
    current_user.customer.venue_ids = venue_lists.flatten
    respond_to do |format|
      format.js { 
        render :update do |page|
          Venue.where('id in (?)',params[:venue_ids]).each do |venue|
            Activity.create_new_activity(current_user.customer.id, venue, "Added new venue to A-List")
            venue_html = escape_javascript(render :partial => "shared/add_remove_alist", :locals => {:venue => venue, :front_page => "friends"})
            page << "$('#in-alist-#{venue.id}').html('#{venue_html}')"
          end
          page << "$('#venue-detail').html('')"
          page << "$('#busy-indicator').hide()"
        end
      }
      format.xml{
        Venue.where('id in (?)',params[:venue_ids]).each do |venue|
          Activity.create_new_activity(current_user.customer.id, venue, "Added new venue to A-List")
        end
        render $COMMON_RESPONSE,:locals=>{:status=>SUCCESS,:partial=>'',:error_fields=>NO_ERROR,:data=>{}}
      }  
    end
  end
  
  def registration_signin
    current_user_session.destroy if current_user
    session.clear
    redirect_to(login_path)
  end
  
  def rating_deal
    deal = Deal.where("id = ?", params[:offer_id]).first
    saved = DealRating.create(:user_id => current_user.id, :deal_id => params[:offer_id],
                    :rating => params[:rate]) unless deal.rated_by_current_user?(current_user.id)
    respond_to do |format|
      format.js { 
        render :update do |page|
          rating_html = escape_javascript(render :partial => "shared/deal_rating", :locals => {:deal => deal})
          page << "$('#rating').html('#{rating_html}')"
          page << "$('#busy-indicator').hide()"
        end
      }
      format.xml{
        if saved.blank?
          render $COMMON_RESPONSE,:locals=>{:status=>FAILURE,:partial=>'',:error_fields=>{:error=>'Already Rated the offer!.'}}
        else
          render $COMMON_RESPONSE,:locals=>{:status=>SUCCESS,:partial=>'',:error_fields=>NO_ERROR}
        end  
      }
    end
  end
  
  def deal_click_count
    deal = Deal.where("id = ?", params[:id]).first
    update_deal_click(deal) unless deal.blank?
    render :nothing => true
  end
  
  def export_redeem_to_pdf
    @deal = Deal.where("id = ?", params[:id]).first
    headers["Content-Disposition"] = "attachment; filename=#{@deal.headline}.pdf"
    render :layout => false
  end
  
  def update_city_selection
    if current_user && current_user.admin? && params[:city] 
      saved = params[:city][:id] == "" ? current_user.admin.update_attribute(:city_id, nil) : current_user.admin.update_attribute(:city_id, params[:city][:id])
    elsif current_user && current_user.user? && params[:city]
      saved = params[:city][:id] == "" ? current_user.customer.update_attribute(:city_id, nil) : current_user.customer.update_attribute(:city_id, params[:city][:id])
    end
    respond_to do |format|
      format.js { 
        render :update do |page|
          page << "$('#busy-indicator').hide()"
        end
      }
      format.xml { if saved 
        render $COMMON_RESPONSE,:locals=>{:status=>SUCCESS, :partial=>'', :error_fields=>NO_ERROR}
      else
        render $COMMON_RESPONSE,:locals=>{:status=>FAILURE, :partial=>'', :error_fields=>{}}
        end}
    end
  end
  
  def decrease_offer_redeem
    deal = Deal.where("id = ?", params[:offer_id]).first
    if !deal.blank? && deal.limited == true && deal.max_redeemed > 0
      saved = deal.update_attribute(:max_redeemed, deal.max_redeemed - 1) 
      Activity.create_new_activity(current_user.customer.id, deal , "Redeemed an offer")
    end
    respond_to do |format|
      format.xml { 
        if !deal.blank? 
          if !saved  && deal.limited == true
            render $COMMON_RESPONSE,:locals=>{:status=>FAILURE, :partial=>'', :error_fields=>{:offer => "Offer not available for redeem."}}	and return
          else
            RedeemedOffer.create(:deal_id=>deal.id,:user_id=>current_user.id)
            deal.update_attribute(:active, false) if deal.max_redeemed == 0 && deal.limited == true
            render $COMMON_RESPONSE,:locals=>{:status=>SUCCESS, :partial=>'', :error_fields=>NO_ERROR}
          end
        else
          render $COMMON_RESPONSE,:locals=>{:status=>FAILURE, :partial=>'', :error_fields=>{:offer => "Invalid Offer."}}
        end
      }
      format.js {
        render :update do |page|
          if !deal.blank? 
            if !saved  && deal.limited == true
              page << "openpopup('Offer not available for redeem.')"
            else  
              RedeemedOffer.create(:deal_id=>deal.id,:user_id=>current_user.id)
              if deal.max_redeemed == 0 && deal.limited == true
                deal.update_attribute(:active, false) 
                redeem_html = escape_javascript(render :partial => "shared/redeem", :locals => {:deal => deal})
                page << "$('#reedem-holder').html('#{redeem_html}')"
              end
              page << "" 
            end
          end
        end
      }
    end
  end
  
  private
    def update_deal_click(deal)
    DealClick.create(:deal_id => params[:id])
    deal.update_attributes(:click_count => (deal.click_count + 1))
  end
end
