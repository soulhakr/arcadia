#
#   ae-ruby-debug.rb - Arcadia Ruby ide
#   by Antonio Galeone <antonio-galeone@rubyforge.org>
#

#require 'whichr'

class RubyDebugView
  include TkUtil
  B_STATE_ON = '+'
  B_STATE_OFF = '-'
  B_STATE_FREEZE = '=' 
  def initialize(_controller)
    @frame = _controller.frame.hinner_frame
    @frame_server = _controller.frame(1).hinner_frame
    @controller = _controller
    self.build_ui
    @controller.rdc.add_listener(self)
    @nodes_to_open = Array.new
    #@break_hash = Hash.new
  end
  
  def build_buttons_set
    _relief = 'groove'
#    @debug_button_box.add(Arcadia.style('toolbarbutton').update({
#      'name'=>'debug_over',
#      'anchor' => 'nw',
#      'command'=>proc{self.debug_send(:step_over)},
#      'helptext'=>'step over',
#      'image'=> TkPhotoImage.new('dat' => D_NEXT_GIF)})
#    )
    @debug_button_box.add(Arcadia.style('toolbarbutton').update({
      'name'=>'debug_over',
    #  'background' => 'white',
      'anchor' => 'nw',
      'command'=>proc{self.debug_send(:step_over)},
      'helptext'=>Arcadia.text('ext.ruby_debug.button.step_over.hint'),
      'image'=> Arcadia.image_res(D_NEXT_GIF),
      'relief'=> _relief })
    )
    @debug_button_box.add(Arcadia.style('toolbarbutton').update({
      'name'=>'debug_into',
    #  'background' => 'white',
      'anchor' => 'nw',
      'command'=>proc{self.debug_send(:step_into)},
      'helptext'=>Arcadia.text('ext.ruby_debug.button.step_into.hint'),
      'image'=> Arcadia.image_res(D_STEP_INTO_GIF),
      'relief'=>_relief })
    )
    @debug_button_box.add(Arcadia.style('toolbarbutton').update({
      'name'=>'debug_out',
    #  'background' => 'white',
      'anchor' => 'nw',
      'helptext'=>Arcadia.text('ext.ruby_debug.button.step_out.hint'),
      'command'=>proc{self.debug_send(:step_out)},
      'image'=> Arcadia.image_res(D_STEP_OUT_GIF),
      'relief'=>_relief })
    )
    @debug_button_box.add(Arcadia.style('toolbarbutton').update({
      'name'=>'debug_resume',
    #  'background' => 'white',
      'anchor' => 'nw',
      'helptext'=>Arcadia.text('ext.ruby_debug.button.resume.hint'),
      'image'=> Arcadia.image_res(D_RESUME_GIF),
      'command'=>proc{self.debug_send(:resume)},
      'relief'=>_relief })
    )

    @debug_button_box.add(Arcadia.style('toolbarbutton').update({
      'name'=>'debug_quit',
    #  'background' => 'white',
      'anchor' => 'nw',
      'helptext'=>Arcadia.text('ext.ruby_debug.button.quit.hint'),
      'image'=> Arcadia.image_res(D_QUIT_GIF),
      'command'=>proc{self.debug_send(:quit)},
      'relief'=>_relief })
    )
    
#    @debug_button_box.bind_append("KeyPress"){|e|
#       case e.keysym
#         when 'F5'
#           self.debug_send(:step_over)  
#       end
#
#    }
  end  
  
  def build_ui
    _y = 22
    @debug_button_box = Tk::BWidget::ButtonBox.new(@frame){
      homogeneous true
      state 'disabled'
      background Arcadia.conf('panel.background')
    }.place('height'=> _y)
    TkWinfo.parent(@debug_button_box).configure(:background => Arcadia.conf('panel.background'))
    
#    @debug_frame = TkFrame.new(@frame, Arcadia.style('panel')){ 
#        border  2
#        place(
#          'y'=>_y,
#          'height'=> -_y,
#          'relheight'=> 1,
#          'relwidth'=> 1
#        )
#    }
    
    self.build_buttons_set
    
    build_process_panel(@frame_server)

#    @enb = Tk::BWidget::NoteBook.new(@debug_frame, Arcadia.style('tabpanel')){
#      tabbevelsize 0
#      internalborderwidth 2
#      place('relwidth' => 1,'relheight' => '1')
#    }
#
#    _tab_var = @enb.insert('end', 'vars' ,
#      'text'=> 'Variables',
#      'raisecmd'=>proc{}
#    )
    
    build_var_panel(@frame)
    @stack_nodes = Array.new
#    @enb.raise('vars')

  end

  def build_process_panel(_frame)
    @tree_process = BWidgetTreePatched.new(_frame, Arcadia.style('treepanel')){
      showlines false
      deltay 15
      place('relwidth' => 1,'relheight' => '1')
    }
    @tree_process.textbind("Double-ButtonPress-1", proc{
      #_selected = @tree_process.selection_get[0]
      _selected = @tree_process.selected
      if @tree_process.parent(_selected)=='client'
        _text = @tree_process.itemcget(_selected, 'text')
        pos = match_position_from_stack(_text)
        if pos && pos.length >0 && File.exists?(pos[0])
    	     Arcadia.process_event(OpenBufferEvent.new(self,'file'=>pos[0], 'row'=>pos[1]))
          #EditorContract.instance.open_file(self, 'file'=>pos[0], 'line'=>pos[1])
        end
      end
    })

  end

  def start_process(_filename)
    @tree_process.insert('end', 'root' ,'server', {
      'text' =>  "Server => #{File.basename(_filename)} at #{@controller.conf('server.host')}:#{@controller.conf('server.port')}"
    }.update(Arcadia.style('treeitem')))
    @tree_process.insert('end', 'server' ,'client', {
      'text' =>  "Client"
    }.update(Arcadia.style('treeitem')))
    @tree_process.open_tree('server',true)
  end

  def tree_var_free
    @tree_var.delete(@tree_var.nodes('local_var'))
    @tree_var.delete(@tree_var.nodes('instance_var'))
    @tree_var.delete(@tree_var.nodes('global_var'))
    @tree_var.delete(@tree_var.nodes('class_var'))
    @tree_var.delete(@tree_var.nodes('eval')) if @tree_var.exist?('eval')
  end

  def tree_process_free
    @tree_process.delete(@tree_process.nodes('root'))
  end

  def bnext_state(_state)
    if _state == B_STATE_ON
      return B_STATE_FREEZE
    elsif _state == B_STATE_FREEZE
      return B_STATE_OFF
    elsif _state == B_STATE_OFF
      return B_STATE_ON
    end   
  end

  def build_var_panel(_frame)
    _open_proc = proc do |_arg|
      inspect_node(_arg) if @c_on && @nodes_to_open && @nodes_to_open.include?(_arg)
    end
        
    @tree_var = BWidgetTreePatched.new(_frame, Arcadia.style('treepanel')){
      showlines false
      deltay 15
      opencmd _open_proc
    }
    
    #.place('relwidth' => 1,'relheight' => '1','bordermode' => 'inside')

    @tree_var.extend(TkScrollableWidget).show(0,26)


#    _scrollcommand = proc{|*args| @tree_var.yview(*args)}
#    _scrollbar = TkScrollbar.new(_frame, Arcadia.style('scrollbar')){|s|
#      width 8
#      command _scrollcommand
#    }.pack('side'=>'right', 'fill'=>'y')
#    @tree_var.yscrollcommand proc{|first,last| _scrollbar.set(first,last)}

    @tree_var.textbind("Double-ButtonPress-1", proc{
      #_selected = @tree_var.selection_get[0]
      _selected = @tree_var.selected
      _msg = @tree_var.itemcget(_selected, 'text')
      Arcadia.dialog(self, 'type'=>'ok','title' => 'Value', 'msg' => _msg, 'level'=>'info')
    })
  
    
    @local_state = B_STATE_ON
    @instance_state = B_STATE_ON
    @class_state = B_STATE_ON
    @global_state = B_STATE_OFF
    
    _i_on = Arcadia.image_res(ON_GIF)
    _i_off = Arcadia.image_res(OFF_GIF)
    _i_freeze = Arcadia.image_res(FREEZE_GIF)

    _b_relief = 'groove'
    #------------------ loacal variables -------------------
    _loc_var_text = Arcadia.text("ext.ruby_debug.node.local_var.caption")
    @b_local_onoff = TkButton.new(@tree_var, Arcadia.style('button')){
        image  _i_on
        state 'disabled'
        anchor 'nw'
    }.bind("1",proc{
      @local_state = bnext_state(@local_state)
      if @local_state == B_STATE_ON
        @tree_var.itemconfigure('local_var',
          'text'=>"#{_loc_var_text}",
          'helptext'=>""
        )
        @b_local_onoff.image(_i_on)
        command_enabled(false)
        Thread.new{
          begin
            update_variables('local_var', @controller.rdc.variables('local_variables')) #if @tree_var.open?('local_var')
          ensure
            command_enabled(true)
          end
        }
      elsif @local_state == B_STATE_FREEZE
        @b_local_onoff.image(_i_freeze)
        @tree_var.itemconfigure('local_var',
          'text'=>Arcadia.text('ext.ruby_debug.freeze_at',[_loc_var_text,@last_position_string]),
          'helptext'=>Arcadia.text('ext.ruby_debug.freeze_at',[_loc_var_text,@last_position_string])
        )
      elsif @local_state == B_STATE_OFF
        @b_local_onoff.image(_i_off)
        @tree_var.delete(@tree_var.nodes('local_var'))
        @tree_var.itemconfigure('local_var',
          'text'=>"#{_loc_var_text}",
          'helptext'=>""
        )
      end
    })

    @tree_var.insert('end', 'root' ,'local_var', Arcadia.style('treeitem').update({
      'fill'=>Arcadia.conf('hightlight.8.foreground'),
      'open'=>true,
      'anchor'=>'w',
      'text' =>  _loc_var_text,
      'window' => @b_local_onoff
    }))

    #------------------ instance variables -------------------
    _instance_var_text=Arcadia.text("ext.ruby_debug.node.instance_var.caption")
    @b_instance_onoff = TkButton.new(@tree_var, Arcadia.style('button')){
        image  _i_on
        #relief _b_relief
        state 'disabled'
        anchor 'nw'
    }.bind("1",proc{
      @instance_state = bnext_state(@instance_state)
      if @instance_state == B_STATE_ON
        @tree_var.itemconfigure('instance_var',
          'text'=>"#{_instance_var_text}",
          'helptext'=>""
        )
        @b_instance_onoff.image(_i_on)
        command_enabled(false)
        Thread.new{
          begin
            update_variables('instance_var', @controller.rdc.variables('instance_variables')) #if @tree_var.open?('local_var')
          ensure
            command_enabled(true)
          end
        }
      elsif @instance_state == B_STATE_FREEZE
        @b_instance_onoff.image(_i_freeze)
        @tree_var.itemconfigure('instance_var',
          'text'=>Arcadia.text('ext.ruby_debug.freeze_at',[_instance_var_text,@last_position_string]),
          'helptext'=>Arcadia.text('ext.ruby_debug.freeze_at',[_instance_var_text,@last_position_string])
        )
      elsif @instance_state == B_STATE_OFF
        @b_instance_onoff.image(_i_off)
        @tree_var.delete(@tree_var.nodes('instance_var'))
        @tree_var.itemconfigure('instance_var',
          'text'=>"#{_instance_var_text}",
          'helptext'=>""
        )
      end
    })
    @tree_var.insert('end', 'root' ,'instance_var', Arcadia.style('treeitem').update({
      'fill'=>Arcadia.conf('hightlight.9.foreground'),
      'open'=>true,
      'anchor'=>'w',
      'text' =>  _instance_var_text,
      'window' => @b_instance_onoff
    }))

    #------------------ class variables -------------------
    _class_var_text=Arcadia.text("ext.ruby_debug.node.class_var.caption")
    @b_class_onoff = TkButton.new(@tree_var, Arcadia.style('button')){
        image  _i_on
        #relief _b_relief
        state 'disabled'
        anchor 'nw'
    }.bind("1",proc{
      @class_state = bnext_state(@class_state)
      if @class_state == B_STATE_ON
        @tree_var.itemconfigure('class_var',
          'text'=>"#{_class_var_text}",
          'helptext'=>""
        )
        @b_class_onoff.image(_i_on)
        command_enabled(false)
        Thread.new{
          begin
            update_variables('class_var', @controller.rdc.variables('self.class.class_variables')) #if @tree_var.open?('local_var')
          ensure
            command_enabled(true)
          end
        }
      elsif @class_state == B_STATE_FREEZE
        @b_class_onoff.image(_i_freeze)
        @tree_var.itemconfigure('class_var',
          'text'=> Arcadia.text('ext.ruby_debug.freeze_at',[_class_var_text,@last_position_string]),
          'helptext'=>Arcadia.text('ext.ruby_debug.freeze_at',[_class_var_text,@last_position_string])
        )
      elsif @class_state == B_STATE_OFF
        @b_class_onoff.image(_i_off)
        @tree_var.delete(@tree_var.nodes('class_var'))
        @tree_var.itemconfigure('class_var',
          'text'=>"#{_class_var_text}",
          'helptext'=>""
        )
      end
    })
    @tree_var.insert('end', 'root' ,'class_var', Arcadia.style('treeitem').update({
      'fill'=>Arcadia.conf('hightlight.10.foreground'),
      'open'=>true,
      'anchor'=>'w',
      'text' =>  _class_var_text,
      'window' => @b_class_onoff
    }))


    #------------------ global variables -------------------
    _global_var_text=Arcadia.text("ext.ruby_debug.node.global_var.caption")
    @b_global_onoff = TkButton.new(@tree_var, Arcadia.style('button')){
        image  _i_off
        #relief _b_relief
        state 'disabled'
        anchor 'nw'
    }.bind("1",proc{
      @global_state = bnext_state(@global_state)
      if @global_state == B_STATE_ON
        @tree_var.itemconfigure('global_var',
          'text'=>"#{_global_var_text}",
          'helptext'=>""
        )
        @b_global_onoff.image(_i_on)
        command_enabled(false)
        Thread.new{
          begin
            update_variables('global_var', @controller.rdc.variables('global_variables')) #if @tree_var.open?('local_var')
          ensure
            command_enabled(true)
          end
        }
      elsif @global_state == B_STATE_FREEZE
        @b_global_onoff.image(_i_freeze)
        @tree_var.itemconfigure('global_var',
          'text'=>Arcadia.text('ext.ruby_debug.freeze_at',[_global_var_text,@last_position_string]),
          'helptext'=>Arcadia.text('ext.ruby_debug.freeze_at',[_global_var_text,@last_position_string])
        )
      elsif @global_state == B_STATE_OFF
        @b_global_onoff.image(_i_off)
        @tree_var.delete(@tree_var.nodes('global_var'))
        @tree_var.itemconfigure('global_var',
          'text'=>"#{_global_var_text}",
          'helptext'=>""
        )
      end
    })
    @tree_var.insert('end', 'root' ,'global_var', Arcadia.style('treeitem').update({
      'fill'=>Arcadia.conf('hightlight.11.foreground'),
      'open'=>true,
      'anchor'=>'w',
      'text' =>  _global_var_text,
      'window' => @b_global_onoff
    }))
  end

#  def build_break_panel(_tab_breakpoint)
#    @tree_break = Tk::BWidget::Tree.new(_tab_breakpoint, Arcadia.style('treepanel')){
#      showlines true
#      deltay 15
#    }.place('relwidth' => 1,'relheight' => '1')
#  end
  
  def file2node_name(_file)
    _s = ""
    _file.gsub("/",_s).gsub(".",_s).gsub(":",_s).gsub("\\",_s).gsub("-",_s)
  end
  
  def line2node_name(_parent, _line)
    "#{_parent}_#{_line.to_s}"
  end
  
#  def break_list_add(_file, _line)
#    _file_node = file2node_name(_file) 
#    _line_node = line2node_name(_file_node, _line)
#    if !@tree_break.exist?(_file_node)
#      @tree_break.insert('end', 'root' ,_file_node, {
#        'open'=>true,
#        'anchor'=>'w',
#        'text' =>  _file
#      }.update(Arcadia.style('treeitem')))
#    end
#    
#    if !@tree_break.exist?(_line_node)
#      @tree_break.insert('end', _file_node ,_line_node, {
#        'open'=>true,
#        'anchor'=>'w',
#        'text' =>  "line: #{_line}"
#      }.update(Arcadia.style('treeitem')))
#    end
#  end

#  def break_list_del(_file, _line)
#    _file_node = file2node_name(_file) 
#    _line_node = line2node_name(_file_node, _line)
#    if @tree_break.exist?(_line_node)
#      @tree_break.delete(_line_node) 
#      _bro = @tree_break.nodes(_file_node)
#      if _bro && _bro.length > 0 
#        @tree_break.delete(_file_node) 
#      end
#    end
#  end

#  def break_list_select(_file, _line)
#    _file_node = file2node_name(_file) 
#    _line_node = line2node_name(_file_node, _line)
#    @tree_break.selection_clear
#    if @tree_break.exist?(_line_node)
#      @tree_break.selection_add(_line_node)
#      @tree_break.see(_line_node)
#    end
#  end

  
#  def break_list_free
#    @tree_break.delete(@tree_break.nodes('root'))
#  end
  
  def clear
    tree_var_free
    tree_process_free
    #break_list_free
  end
  
  
  def rdebug_client_update(_command, _result)
    #Arcadia.console(self,'msg'=>"on command #{_command} => #{_result}", 'level'=>'debug')
    return if @controller.rdc.nil? || !@controller.rdc.is_debugging_ready? || !@controller.rds.is_alive?
    begin
      if _command == 'quit'
#        msg = "Really quit debug ? (y/n)"
        ans = 'yes'#Tk.messageBox('icon' => 'question', 'type' => 'yesno',
#        'title' => '(Arcadia) Debug', 'message' => msg)
        if  ans == 'yes'
          debug_send(:quit_yes)
          clear
        else
          debug_send(:quit_no)
        end
      elsif _command == 'quit_yes'
          clear
      elsif  _command == 'quit_no'
        command_enabled(true)
      elsif _command == 'cont' && !_result.downcase.include?('breakpoint')
        @controller.rdc.kill
        clear
      elsif _command != 'where' && _command != 'quit_yes'  && @controller.rdc.is_alive?
        begin
          update_position
          if @controller.rdc.is_alive?
            update_variables('local_var', @controller.rdc.variables('local_variables')) if @local_state == B_STATE_ON
            update_variables('instance_var', @controller.rdc.variables('instance_variables')) if @instance_state == B_STATE_ON
            update_variables('class_var', @controller.rdc.variables('self.class.class_variables')) if @class_state == B_STATE_ON
            #Arcadia.new_debug_msg(self,"on command #{_command}:global_variables")
            update_variables('global_var', @controller.rdc.variables('global_variables')) if @global_state == B_STATE_ON
          end
        ensure
          command_enabled(true) if !@controller.rdc.nil? && @controller.rdc.is_debugging_ready? && (!_command.include?('quit') || _command.include?('quit_no')) 
        end
      end
    rescue Exception => e
      Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.client.e.on_command', [_command, e.inspect]), 'level'=>'debug')
      #Arcadia.new_debug_msg(self,"on command #{_command}:#{e.inspect}")
    end
  end

  def match_position_from_stack(_line)
    #Arcadia.new_error_msg(self, "match on #{_line}")
    ret = Array.new
    #matchline = _line.match(/#*([0-9]*)[\s\w\W]*\s([\w\:]*[\.\/]*[\/A-Za-z_\-\.]*[\.\/\w\d]*):(\d*)/)
    matchline = _line.match(/#*([0-9]*)[\s\w\W]*line\s(.*):([0-9]*)(.*)/)
    if !matchline.nil? && matchline.length==5
      filename = matchline[2].to_s.strip
      line_no = matchline[3].to_i 
    else
      matchline = _line.match(/[lL]ine\s(.*)[:]*([0-9]*)\sof\s\"(.*)\"/)
      if !matchline.nil? && matchline.length==4
        filename = matchline[3].to_s.strip
        line_no = matchline[1].to_i 
      end
    end  
    if filename && line_no
      ret << filename << line_no
    end
    ret
  end
  
  def update_position
    stack = @controller.rdc.where
    #Arcadia.new_debug_msg(self,stack)
    if !stack.nil?
      stack = stack.split(/\n/)
      line_no = -1
      if stack.length > 1 && stack[1].strip[0..0]!='#'
        pos = match_position_from_stack(stack[1].strip)
      elsif !stack[0].nil?
        pos = match_position_from_stack(stack[0])
      end
      if pos && pos.length > 0
        _file = pos[0]
        _file = File.expand_path(pos[0]) if !File.exist?(_file)
        Arcadia.broadcast_event(DebugStepInfoEvent.new(self,'file'=> _file, 'row'=>pos[1]))
        #DebugContract.instance.debug_step(self, 'file'=> _file, 'line'=>pos[1])
        #break_list_select(_file, pos[1].to_s)
        @last_position_string = "#{pos[0]}:#{pos[1]}"
      end
      i = 0
      @tree_process.delete(@stack_nodes)
      stack.each do |line| 
        _node = "c#{i.to_s}"
        @tree_process.insert('end', 'client' ,_node, {
          'text' =>  line,
          'helptext' => line
        }.update(Arcadia.style('treeitem')))
        #Arcadia.console(self, 'msg'=>"inserted line #{line}")
        @stack_nodes << _node
        i = i+1
      end
    end
  end

  def is_simple_class?(_var)
    ['Numeric','Fixnum','String','FalseClass','TrueClass','NilClass','Float','BigDecimal','Bignum','Symbol'].include?(_var.value_class) && !_var.value.to_s.strip.include?("\n")
  end
  
  def show_expression(_exp, _hash)
    if !@tree_var.exist?('eval')
      @tree_var.insert('end', 'root' ,'eval', Arcadia.style('treeitem').update({
        'fill'=>Arcadia.conf('hightlight.13.foreground'),
        'open'=>true,
        'anchor'=>'w',
        'text' =>  Arcadia.text("ext.ruby_debug.node.eval_selected")
      }))
    end
    update_variables('eval', _hash)
  end
  
  def inspect_node(_node)
    command_enabled(false)
    begin
      _var = var_name(_node)
      _o = @controller.rdc.debug_dump(_var)
      if _o.class == Hash
        var_deep(_node, _o)
      else 
        var_deep_string(_node, _o)
      end
    ensure
      command_enabled(true)
    end
  end
  
  def var_deep(_var, _hash)
#    _var_cla = _hash['__CLASS__']
#    _var_len = _hash['__LENGTH__']
#    @tree_var.itemconfigure(_var, 'text' =>  "#{_var_cla}:#{_var_len}")
    return nil if _hash.nil? 
    return _hash.to_s if _hash.class != Hash
    if _hash['__CLASS__']=='Array'
     _sorted_keys = _hash.keys.collect!{|x| x.to_i}.sort.collect!{|x| x.to_s}
    else
     _sorted_keys = _hash.keys.collect!{|x| x.to_s}.sort
    end
    _sorted_keys.each{|k|
    #_hash.keys.sort.each{|k|
      v = _hash[k]
      next if k=='__CLASS__'
      _complex = v.class == Hash
      if _complex
        _text = var_format(k,v['__CLASS__'])
      elsif (k=='__LENGTH__') && v=='0'
        _text = '{}'
      elsif (k=='__LENGTH__') && v!='0'
        next
      elsif _hash['__CLASS__']=='Array'
        _text = var_format(k.rjust(_hash['__LENGTH__'].length),nil,v,false)
      else
        _text = var_format(k,nil,v)
      end
      _node = node_name(k, _var)
      if @tree_var.exist?(_node)
        @tree_var.itemconfigure(_node, 'text' =>  _text)
      else
        @tree_var.insert('end', _var ,_node, Arcadia.style('treeitem').update({
          'text' =>  _text,
          'helptext' => v,
          'anchor'=>'w'
        }))
      end
      var_deep(_node,v) if _complex
    }
  end

  def var_deep_string(_var, _str)
    @tree_var.delete(@tree_var.nodes(_var))
    return nil if _str.nil? 
    _str = _str.to_s if !_str.kind_of?(String)
    a_str = _str.split("\n")
    a_str.each_with_index{|v,i|
      _node = node_name(i.to_s, _var)
      @tree_var.insert('end', _var ,_node, Arcadia.style('treeitem').update({
        'text' =>  v,
        'fill' => Arcadia.conf('hightlight.12.foreground'),
        'anchor'=>'w'
      }))
    }
  end

  
  def var_format(_name, _class, _value=nil, _strip_name=true)
    if _strip_name
      _name = _name.to_s.strip
    else
      _name = _name.to_s
    end
    if !_value.nil? && !_class.nil?
      return "#{_name} => #{_value.to_s.strip} [#{_class.to_s.strip}]"
    elsif _value.nil? && !_class.nil?
      return "#{_name} [#{_class.to_s.strip}]"
    elsif !_value.nil? && _class.nil?
      return "#{_name} => #{_value.to_s.strip}"
    elsif _value.nil? && _class.nil?
      return "#{_name} => {}"
    end
  end
  
  def node_name(_node, _parent)
    return "#{_parent}@@@#{_node.to_s.gsub('$','__S__').gsub('&','__E__').gsub(':','__D__').gsub('!','__A__')}" 
  end

  def var_name(_node)
    #_parent = @tree_var.parent(_node)
    #return _node.sub("#{_parent}_", '') 
    to_split= _node
    if _node.instance_of?(Array) && _node.length > 0
      to_split=_node[0].to_s
    end
    return to_split.split('@@@')[-1].gsub('__S__','$').gsub('__E__','&').gsub('__D__',':').gsub('__A__','!')
  end
  
  def command_enabled(_value)
    #Arcadia.new_debug_msg(self,"command_enabled= #{_value.to_s}")
    @c_on = _value
    _value ? _state = 'normal':_state = 'disabled'
    @debug_button_box.configure(:state=>_state) 
    @b_local_onoff.configure(:state=>_state) 
    @b_instance_onoff.configure(:state=>_state) 
    @b_class_onoff.configure(:state=>_state) 
    @b_global_onoff.configure(:state=>_state) 
    Tk.update
  end

  def update_variables(_parent_node, _var)
    #Arcadia.console(self, 'msg'=>"---update_variables =>#{_var} figlio di #{_parent_node}")
    if _var.keys.sort == @tree_var.nodes(_parent_node).collect! {|x| var_name(x).to_s}.sort
      _var.each{|k,v|
        #Arcadia.console(self, 'msg'=>"node_name of #{k}")
        _n = node_name(k, _parent_node)
        if is_simple_class?(v)
          _text = var_format(k,v.value_class,v.value)
          _drawcross = 'auto'
        else
          _text = var_format(k,v.value_class)
          _drawcross = 'always'
          @nodes_to_open << _n if !@nodes_to_open.include?(_n)
          inspect_node(_n) if bool(@tree_var.itemcget(@tree_var.tagid(_n), 'open'))
        end
        #Arcadia.console(self, 'msg'=>"_n=#{_n} text=#{_text}")
        _node = @tree_var.itemconfigure(_n, 
          'text' =>  _text, 
          'helptext' => v.value,
          'drawcross' => _drawcross
        )
      }          
    else 
      @nodes_to_open.clear
      @tree_var.delete(@tree_var.nodes(_parent_node))
      #@nodes[_parent_node].clear
      _var.keys.sort.each{|k|
          v = _var[k]
          _n = node_name(k, _parent_node)
          if is_simple_class?(v)
            _text = var_format(k,v.value_class,v.value)
            _drawcross = 'auto'
          else
            _text = var_format(k,v.value_class)
            _drawcross = 'always'
            @nodes_to_open << _n
          end
          @tree_var.insert('end', _parent_node ,_n, Arcadia.style('treeitem').update({
            'text' =>  _text,
            'helptext' => v.value,
            'drawcross' => _drawcross,
            'anchor'=>'w'
          }))
      }
    end
    Tk.update
  end

  def debug_send(_command)
    if @controller.rdc
      begin
        command_enabled(false)
        #@debug_button_box.configure(:state=>'disabled')
        Thread.new do
          Arcadia.process_event(StepDebugEvent.new(self, 'command'=>_command))
          #@controller.rdc.send(_command)
        end
        #@controller.rdc.send(_command)
      rescue Exception => e
        Arcadia.console(self, 'msg'=>"---> "+e.to_s + ' ' + e.backtrace[0], 'level'=>'debug')
        #Arcadia.new_debug_msg(self,"---> "+e.to_s)
      end
    end
  end
end

class RubyDebugException < Exception
end

class RubyDebugServer
  include Observable
  attr_accessor :quit_confirm_request
  RDS_QUIET = 'RDS_QUIET'
  def initialize(_caller, _arcadia=nil)
    if _caller.respond_to? :rdebug_server_update
      ObserverCallback.new(self,_caller,:rdebug_server_update)
    end
    @arcadia = _arcadia
    @rdebug_file = _caller.rdebug_file
    @quit_confirm_request = false
    @alive = false
  end

  def start_session_new(_filename, _host='localhost', _remote_port='8989')
    commandLine = "#{@rdebug_file} --host #{_host} --port #{_remote_port} -sw #{_filename}"
    #Arcadia.process_event(SystemExecEvent.new(self, 'command'=>commandLine))
    Arcadia.process_event(RunCmdEvent.new(self, 'cmd'=>commandLine, 'file'=>_filename))
  end
  
  def is_alive?
    @alive
  end
  
  def set_alive(_value=false)
    @alive = _value
  end
  
  def start_session(_debug_event, _host='localhost', _remote_port='8989')
    _filename = _debug_event.file
    commandLine = "#{Arcadia.ruby} #{@rdebug_file} --host #{_host} --port #{_remote_port} -sw '#{_filename}'"
    #p commandLine
    begin
      @alive = true
      if Arcadia.is_windows?
        @tid = Thread.new do
          if Kernel.system(commandLine)
              Kernel.system('y')
          else
            if @quit_confirm_request
              Arcadia.console(self, 'msg'=>"#{$?.inspect}")
              #Arcadia.new_msg(self,"#{$?.inspect}")    
            else
              _event = Arcadia.process_event(RunCmdEvent.new(self, {'file'=>_filename}))
              Arcadia.console(self, 'msg'=>"#{_event.results[0].output}", 'level'=>'debug')
              #Arcadia.new_debug_msg(self,"#{_event.results[0].output}")    
            end
          end
          set_alive(false)
          notify(RDS_QUIET)
          if _debug_event.persistent == false && File.basename(_debug_event.file)[0..1] == '~~'
             File.delete(_debug_event.file) if File.exist?(_debug_event.file)
          end

        end
      else
        @pid = Process.fork do
          if File.basename(Arcadia.ruby) != 'ruby'
            commandLine="export PATH=#{Arcadia.instance.local_dir}/bin:$PATH && #{commandLine}"
          end
          #s_event = Arcadia.process_event(RunCmdEvent.new(self, {'cmd'=>commandLine}))
          #if s_event.flag != Event::FLAG_ERROR
          if Kernel.system(commandLine)
            set_alive(false)
            notify(RDS_QUIET)
            Kernel.system('y')
            if _debug_event.persistent == false && File.basename(_debug_event.file)[0..1] == '~~'
               File.delete(_debug_event.file) if File.exist?(_debug_event.file)
            end
            Kernel.exit!
          else
            set_alive(false)
            notify(RDS_QUIET)
            Kernel.exit!
            Arcadia.console(self, 'msg'=>"#{$!.inspect}", 'level'=>'debug')
          end
        end
      end
    rescue Exception => e
      Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.server.e.on_start', [e.class, e.message]), 'level'=>'debug')
      #Arcadia.new_debug_msg(self,"Error on start_server : #{e.class}:#{e.message}")    
    end
  end
  
  def kill
    begin
      if Arcadia.is_windows?
        @tid.join(2)
        @tid.kill!
      else
        Process.kill('QUIT',@pid)
      end
      notify(RDS_QUIET)
    rescue Exception => e
      Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.server.e.on_kill', [e.class, e.message]), 'level'=>'debug')
    end
  end
  
  def notify(_state)
     #p "----- notify ----- #{_state}"
     changed
     notify_observers(_state)
  end
  
end

#Ruby-debug commands

#    * b[reak]
#      list breakpoints
#    * b[reak] [file|class:]LINE|METHOD [if expr]
#    * b[reak] [class.]LINE|METHOD [if expr]
#      set breakpoint to some position, optionally if expr == true
#    * cat[ch]
#      show catchpoint
#    * cat[ch] EXCEPTION
#      set catchpoint to an exception
#    * disp[lay] EXPRESSION add expression into display expression list
#    * undisp[lay][ nnn]
#      delete one particular or all display expressions if no expression number given
#    * del[ete][ nnn]
#      delete some or all breakpoints (get the number using break)
#    * c[ont]
#      run until program ends or hit breakpoint
#    * r[un]
#      alias for cont
#    * s[tep][ nnn]
#      step (into methods) one line or till line nnn
#    * n[ext][ nnn]
#      go over one line or till line nnn
#    * w[here]
#      displays stack
#    * f[rame]
#      alias for where
#    * l[ist][ (-|nn-mm)]
#      list program, - list backwards, nn-mm list given lines. No arguments keeps listing
#    * up[ nn]
#      move to higher frame
#    * down[ nn]
#      move to lower frame
#    * fin[ish]
#      return to outer frame
#    * q[uit]
#      exit from debugger
#    * v[ar] g[lobal]
#      show global variables
#    * v[ar] l[ocal]
#      show local variables
#    * v[ar] i[nstance] OBJECT
#      show instance variables of object
#    * v[ar] c[onst] OBJECT
#      show constants of object
#    * m[ethod] i[nstance] OBJECT
#      show methods of object
#    * m[ethod] CLASS|MODULE
#      show instance methods of class or module
#    * th[read] l[ist]
#      list all threads
#    * th[read] c[ur[rent]]
#      show current thread
#    * th[read] [sw[itch]] nnn
#      switch thread context to nnn
#    * th[read] stop nnn
#      stop thread nnn
#    * th[read] resume nnn
#      resume thread nnn
#    * p EXPRESSION
#      evaluate expression and print its value
#    * pp EXPRESSSION
#      evaluate expression and print its value
#    * h[elp]
#      print this help
#    * RETURN KEY
#      redo previous command. Convenient when using list, step, next, up, down,
#    * EVERYHTING ELSE
#      evaluate


class RubyDebugClient
  require 'socket'
  require 'yaml'
  include Observable
  Var = Struct.new("Var",
    :value,
    :value_class
  )
  
  if RUBY_VERSION >= '2'
    #require "psych"
    DOMAIN_TYPE_CONSTANT = nil
  elsif RUBY_VERSION > '1.9.1' && RUBY_VERSION < '2'
    require "syck"
    DOMAIN_TYPE_CONSTANT = Object::Syck::DomainType
  else
    DOMAIN_TYPE_CONSTANT = YAML::DomainType
  end
  
  def initialize(_controller, _server='localhost', _port=8989, _timeout=0)
    @controller = _controller
    @session = nil
    @server = _server
    @port = _port
    @timeout = _timeout.to_i
    @busy = false
    @pend = false
  end
  
  def add_listener(_caller, _method=:rdebug_client_update)
    if _caller.respond_to? :rdebug_client_update
      ObserverCallback.new(self,_caller,:rdebug_client_update)
    end
  end
  
  def notify(_command, _result=nil)
   #Arcadia.new_debug_msg(self,"notify=>#{_command}")    
    @busy = false
    changed
    notify_observers(_command, _result)
    _result
  end

  def is_debugging_ready?
    is_alive? && !is_busy?
  end
  
  def is_busy?
    @busy
  end

  def is_alive?
    #p "===>@session=#{@session}" 
    #p "===>@session.closed?=#{@session.closed?}" if @session
    #p "===>@pend=#{@pend}"
    !(@session.nil? || @session.closed? || @pend)
    #(!@session.nil? && !@session.closed? && !@pend)
  end

  def socket_session
      #p "====>socket_session"
      #Arcadia.new_debug_msg(self,"socket_session : passo")    
      if @session.nil? && @controller.rds.is_alive?
        begin
          #sleep(2)
          @session = TCPSocket.new(@server, @port)
          #@session = IO.popen("|rdebug -c --cport #{@port}",'r+')
          @pend = false
        rescue Errno::ECONNREFUSED,Errno::EBADF => e
          sleep(1)
          @t = @t -1
          if @t > 0
            socket_session
          else
            Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.client.e.socket_session.1', [e.inspect]), 'level'=>'debug')
            #Arcadia.new_debug_msg(self,"socket_session : #{e.inspect}")    
          end
        rescue Exception => e
          @session = nil          
          Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.client.e.socket_session.2', [e.class,e.message]), 'level'=>'debug')
          #Arcadia.new_debug_msg(self,"Error on socket_session : #{e.class}:#{e.message}")    
        end
      elsif !@controller.rds.is_alive?
        @session = nil
      end
      #Arcadia.new_debug_msg(self,"session : #{@session.inspect}")    
      #p "@session=>#{@session}"
      return @session 
  end
  
  def kill 
    begin
      @session.close if is_alive?
      @session=nil
    rescue Exception => e
      Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.client.e.close_session',[e.class,e.message]), 'level'=>'debug')
      #Arcadia.new_debug_msg(self,"Error on close session : #{e.class}:#{e.message}")    
    end
  end
  
  def start_session
    begin
      #p "======>start session"
      @t = @timeout 
      if socket_session
        #Arcadia.new_debug_msg(self,"session : #{@session.inspect}")    
        notify('start', read)
        read("eval require 'yaml'")
      end
      return @session
    rescue Exception => e
      Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.client.e.start_session', [e.class, e.message], e.backtrace.join('..')), 'level'=>'debug')
      #Arcadia.new_debug_msg(self,"Error on start_session : #{e.class}:#{e.message}")    
    end
  end
  
  def stop_session
    begin
      quit if is_debugging_ready?
      @session.close if is_alive?
    rescue Exception => e
      Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.client.e.stop_session', [e.class, e.inspect]), 'level'=>'debug')    
      #Arcadia.new_debug_msg(self,"Error on stop_session : #{e.class}:#{e.inspect}")    
    end
  end
  
  # send a command to the debugger via socket
  def command(_command)
   #Arcadia.new_debug_msg(self,"command=>#{_command}")    
    begin
      return false if @busy 
      if is_alive?
        @busy = true
        #p "sending #{_command}"
        @session.puts(_command) if socket_session
      else
        start_session if !@pend
      end
      #_command !="cont"
      true 
    rescue Errno::ECONNABORTED,Errno::ECONNRESET, Errno::EPIPE => e
      notify("quit_yes")
      #DebugContract.instance.debug_end(self)
      Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.client.e.abort_session', [_command, e.class, e.inspect]), 'level'=>'debug')
      @session = nil
      @pend = true
      false
      #raise RubyDebugException.new("Debugged has finished executing")
    rescue Exception => e
      Arcadia.console(self, 'msg'=>Arcadia.text('ext.ruby_debug.client.e.on_command2', [_command, e.class, e.inspect]), 'level'=>'debug')
      false
    end
  end
  private :command

  def read(_command=nil)
    return nil if _command && !command(_command)
    #return nil if _command.nil? || (_command && !command(_command)) 
    result = ""
    if socket_session
      @session.flush
      while _command !='y' && is_alive? && line = @session.gets
        break if line =~ /^PROMPT (.*)$/ || line =~ /.(y\/n)./ 
        result << line
        #break if _command =~ /^eval./
      end
      #Arcadia.new_debug_msg(self, "read: letta per '#{_command}' result => #{result}")
    end
    @busy = false
    result
  rescue Errno::ECONNABORTED, Errno::ECONNRESET
    raise RubyDebugException.new(Arcadia.text("ext.ruby_debug.client.e.raise.on_read.1"))
  rescue Exception => e
  
    raise RubyDebugException.new(Arcadia.text("ext.ruby_debug.client.e.raise.on_read.2", [_command, e.class, e.inspect]))
  end
  private :read


  def step_over
    notify("next", read("next"))
  end

  def step_into
    notify("step", read("step"))
  end

  def step_out
    notify("fin", read("fin"))
  end

  def resume
    notify("cont", read("cont"))
  end

  def where
#    notify("where", read("where"))
    notify("where", read("info line"))
  end

  def quit
    notify("quit", read("q"))
  end

  def quit_yes
    notify("quit_yes", read("y"))
    #DebugContract.instance.debug_end(self)
    kill
  end

  def quit_no
    notify("quit_no", read("n"))
  end

  # return the current stack trace
  def stacktrace
    notify("backtrace", read("backtrace"))
  end
  

  def yaml_pseudo_load(_obj)
    just_present =  @valuobjs.include?(_obj)
    @valuobjs << _obj 
    p  _obj.class
    if _obj.class == DOMAIN_TYPE_CONSTANT
      
      p _obj
      
      return _obj.type_id if just_present
      ret = Hash.new
      ret['__CLASS__']=_obj.type_id
      l = _obj.value.length  
      ret['__LENGTH__']= l.to_s
      if l > 0 
          _obj.value.each{|k,v|
              ret["@#{k}"]=yaml_pseudo_load(v)
          }
      end
      ret
    elsif _obj.class == Hash
    #Arcadia.new_msg(self,"_obj Hash="+_obj.inspect)
      return 'Hash' if just_present
      ret = Hash.new
      ret['__CLASS__']= 'Hash'
      l = _obj.length  
      ret['__LENGTH__']= l.to_s
      if l > 0 
        _obj.each{|k,v|
            ret[k]=yaml_pseudo_load(v)
        }
      end
      ret
    elsif _obj.class == Array
    #Arcadia.new_msg(self,"_obj Array="+_obj.inspect)
      return 'Array' if just_present
      ret = Hash.new
      ret['__CLASS__']= 'Array'
      l = _obj.length  
      ret['__LENGTH__']= l.to_s
      if l > 0 
        _obj.each_with_index{|v,i|
          ret[i.to_s]=yaml_pseudo_load(v)
        }
      end
      ret
    elsif _obj.class == Struct
    #Arcadia.new_msg(self,"_obj Array="+_obj.inspect)
      return 'Struct' if just_present
      ret = Hash.new
      ret['__CLASS__']= 'Struct'
      l = _obj.length  
      ret['__LENGTH__']= l.to_s
      if l > 0
         
        _obj.members.each{|m|
          ret[m]=yaml_pseudo_load(_obj[m])
        }
      end
      ret
    else  
    #Arcadia.new_msg(self,"_obj ="+_obj.inspect)
    
      _obj
    end
  
  end

  
  def debug_dump(_exp)
    return '' if _exp.nil? || _exp.strip.length == 0 || _exp.strip.length == 'nil'
     var = nil
    if @valuobjs.nil?
      @valuobjs = Array.new 
    else
      @valuobjs.clear
    end
    begin
      _to_eval = read("eval YAML::dump(#{_exp})")
      if _to_eval.include?('Exception:') || _to_eval.include?('SyntaxError:')
        _to_eval = read("eval require 'pp';eval #{_exp}.pretty_inspect")
        var = eval(_to_eval)
        #var = "?"
      else
        _str = "#{eval(_to_eval)}"
        _str.gsub!('!ruby/object:', '!')
        begin
          _obj = YAML::load(_str)
        rescue Exception => e
          Arcadia.console(self, 'msg'=>"exception on eval in YAML::load #{_str} :#{e.inspect}")
        end
        var = yaml_pseudo_load(_obj)
      end  
    rescue Exception => e
      Arcadia.console(self, 'msg'=>"exception on eval #{_exp} :#{e.inspect}")
      Arcadia.console(self, 'msg'=>"exception on eval #{_exp} : #{_to_eval}")
      #Arcadia.new_msg(self,"exception on eval #{_exp} :#{e.inspect}")
      var = nil
    end
    return var
  end

  # returns the local variables and there values
  def variables(_type)
    begin
      #variables = read[1..-2].split(', ').collect!{|x| x[1..-2]}
      to_eval = read("eval #{_type}")
      #Arcadia.console(self,'msg'=>"to_eval=#{to_eval.to_s}")
      variables = eval(to_eval)
      if variables.class != Array
        variables = []
      end
      #Arcadia.console(self,'msg'=>"variables=#{variables.to_s}")
    rescue Exception => e
      variables = []
      #p "on command eval #{_type}:#{e.inspect}"
      #Arcadia.new_debug_msg(self,"on command eval #{_type}:#{e.inspect}")
    end
    variables = [] if variables.nil?
    variable_values = Hash.new
    variables.each do |var|
      next if var.to_s=='$;'
      variable_values[var.to_s] = debug_eval(var.to_s)
    end
    return variable_values
  end

  def debug_eval(_exp)
    if command("eval #{res=_exp}.to_s + '|||' + #{res}.class.to_s")
      begin
        _str = eval(read).to_s
        _value, _class = _str.split('|||')
      rescue Exception => e
        _value = "?"
        _class = "?"
      end
      return Var.new(_value, _class)
    else
      return Var.new("?", "?")
    end
  end

  def set_breakpoint(_file, _line)
    #_line = _line + 1
    text = read("break #{_file}:#{_line}")
    return if text.nil?
    #p text
    breakpoint_no = -1
    #matches = text.match(/Set breakpoint ([0-9]*)?/)
    matches = text.downcase.match(/breakpoint ([0-9]*)?/)
    #Arcadia.new_error_msg(self, "text=#{text}")
    #Arcadia.new_error_msg(self, "matches[1]=#{matches[1]}")
    breakpoint_no = matches[1].to_i if matches && (matches.length == 2)
    return breakpoint_no
  end

  def unset_breakpoint(_id)
    read("delete #{_id}")
  end
end

class RubyDebug < ArcadiaExt
  attr_reader :rds
  attr_reader :rdc
  attr_reader :rdebug_file
  def on_before_build(_event)
    #if RubyWhich.new.which("rdebug") != []
    @breakpoints = Hash.new
    @static_breakpoints = Array.new
    if Arcadia.is_windows?
      @rdebug_file = Arcadia.which("rdebug.bat")
      if !@rdebug_file
        @rdebug_file = Arcadia.which("rdebug.cmd")
      end
      if !@rdebug_file
        @rdebug_file = Arcadia.which("rdebug")
      end      
    else
      @rdebug_file = Arcadia.which("rdebug")    
    end
    
    
    if @rdebug_file
      Arcadia.attach_listener(self, BufferEvent)
    else
      Arcadia.console(self, 'msg'=>Arcadia.text("ext.ruby_debug.e.rdebug"), 'level'=>'error')
      #Arcadia.new_error_msg(self, "Warning: Extension ae-ruby-debug depend upon rdebug command (install it or update system path!)")
    end
    Arcadia.attach_listener(self, DebugEvent)
  end

  def on_build(_event)
    #Arcadia.attach_listener(self, DebugEvent)
  end

  def on_buffer(_event)
    case _event
      when BufferRaisedEvent
        @raised_file=_event.file
        debugcurr = Arcadia.toolbar_item('debugcurr')
        debugcurr.enable=_event.lang=='ruby' if debugcurr
    end
  end

  def on_debug(_event)
    case _event
      when StartDebugEvent
        return if _event.file.nil?
        _filename = _event.file
        _filename = @arcadia['pers']['run.file.last'] if _filename == "*LAST"
        if _filename && File.exist?(_filename)
          do_debug(_event)
        else
          Arcadia.dialog(self,
            'type'=>'ok',
            'title'=>Arcadia.text('ext.ruby_debug.d.file_not_exist.title'),
            'msg'=>Arcadia.text('ext.ruby_debug.d.file_not_exist.msg', [_filename]))
        end
      when StepDebugEvent
        if (_event.command == :quit_yes)
          @rds.quit_confirm_request = true
        end
        @rdc.send(_event.command) if @rdc.is_alive?
        
        #p "on_debug -> Thread.current=#{Thread.current}"

        #p "on_debug --> @rdc.is_alive?=#{@rdc.is_alive?}"
        #p "on_debug --> @rds.is_alive?=#{@rds.is_alive?}"
      when SetBreakpointEvent
        if _event.file
          self.breakpoint_add(File.expand_path(_event.file), _event.row)
        elsif _event.id
          self.breakpoint_add(_event.id, _event.row)
        end
      when UnsetBreakpointEvent
        return if _event.file.nil?
        self.breakpoint_del(File.expand_path(_event.file), _event.row)
      when EvalExpressionEvent
        eval_expression(_event.expression)
      when StopDebugEvent
        self.debug_quit
    end
  end

  
#  def do_editor_event(_event)
#    case _event.signature 
#      when EditorContract::BREAKPOINT_AFTER_CREATE
#        self.breakpoint_add(File.expand_path(_event.context.file), _event.context.line)
#      when EditorContract::BREAKPOINT_AFTER_DELETE
#        self.breakpoint_del(File.expand_path(_event.context.file), _event.context.line)
#      when EditorContract::BUFFER_AFTER_RAISE
#        @raised_file=_event.context.file
#      when EditorContract::EVAL_EXPRESSION
#        eval_expression(_event.context.text)
#    end
#  end

  def eval_expression(_exp)
    res = @rdc.debug_eval(_exp) if @rdc && @rdc.is_debugging_ready?
    hash = Hash.new
    hash[_exp]=res 
    @rdv.show_expression(_exp, hash) if res 
  end
  
  def start_debug_server
  end
  private :start_debug_server
  
  def start_debug_client
  end
  private :start_debug_client
  
  
  def breakpoint_suf(_file,_line)
    return _line.to_s + "-" + _file.to_s
  end
  private :breakpoint_suf
  
  def break_name(_file,_line)
    "#{_file}:#{_line}"
  end
  
  def breakpoint_add_live(_file,_line)
    if @rdc && @rdc.is_alive?
      @breakpoints[breakpoint_suf(_file,_line)] = @rdc.set_breakpoint(_file, _line.to_i)
      #@rdv.break_list_add(_file,_line) if @rdv
    end
  end

  def breakpoint_del_live(_file,_line)
    if @rdc && @rdc.is_alive?
      @rdc.unset_breakpoint(@breakpoints.delete(breakpoint_suf(_file,_line)))
      #@rdv.break_list_del(_file,_line) if @rdv
    end
  end

  def breakpoint_free_live
    @breakpoints.clear if @breakpoints
    #@rdv.break_list_free if @rdv
  end
  
  def breakpoint_add(_file,_line)
    breakpoint_add_live(_file,_line)
    @static_breakpoints << {:file=>_file,:line=>_line}
  end
  #private :breakpoint_add
  def static_breakpoints_of_file(_filename)
    ret = Array.new
    @static_breakpoints.each{|b|
      if b[:file]==_filename
        ret << b
      end
    }
    ret
  end

  def breakpoint_del(_file,_line)
    breakpoint_del_live(_file,_line)
    @static_breakpoints.delete_if{|b| (b[:file]==_file && b[:line]==_line)}
  end
  #private :breakpoint_del


  def on_exit_query(_event)
    if @rdc && @rdc.is_alive?
      query = (Arcadia.dialog(self, 'icon' => 'question', 'type' => 'yes_no',
      'title' => Arcadia.text("ext.ruby_debug.d.exit_query.title"),
      'message' => Arcadia.text("ext.ruby_debug.d.exit_query.msg"))=='yes')
      if query
        debug_quit
        _event.can_exit=true
      else
        _event.can_exit=false
      end
    else
      _event.can_exit=true
    end
  end

  def debug_last
    Arcadia.process_event(StartDebugEvent.new(self, 'file'=>$arcadia['pers']['run.file.last']))
    #debug($arcadia['pers']['run.file.last'])
  end

  def debug_current
    Arcadia.process_event(StartDebugEvent.new(self, 'file'=>@raised_file)) if @raised_file!=nil
    #debug(@raised_file) if @raised_file!=nil
  end
  def debugging?
    !@rdc.nil? && @rdc.is_alive?
  end

  def debug_begin
    breakpoint_free_live
    #DebugContract.instance.debug_begin(self)
  end

  def do_debug(_event)
    _filename = _event.file
    if _filename && !debugging?
      begin
        self.debug_begin
        @arcadia['pers']['run.file.last']=_filename if _event.persistent
        @rds = RubyDebugServer.new(self,@arcadia) if @rds.nil?
        @rds.start_session(_event, conf('server.host'), conf('server.port'))
        #Arcadia.new_msg(self,@rds.to_s)
        
        @rdc = RubyDebugClient.new(self, conf('server.host'), conf('server.port'), conf('server.timeout')) if @rdc.nil?
        @rdv = RubyDebugView.new(self) if @rdv.nil?
        self.frame.show
        @rdv.start_process(_filename)
        if @rdc.start_session
          @static_breakpoints.each{|_b|
            if !_event.persistent && _b[:file]==_event.id
              _b[:file]=_filename
            end
            #Arcadia.console(self,'msg'=>" breakpoint_add #{_b[:file]}:#{_b[:line]}")
            breakpoint_add_live(_b[:file], _b[:line])
          }
          if static_breakpoints_of_file(_filename).length > 0 && conf("auto_resume_break_on_first_line")!='no'
            @rdv.debug_send(:resume)
          end
        end
      rescue Exception => e
        Arcadia.console(self, Arcadia.text('ext.ruby_debug.e.do_debug', [e.to_s, e.backtrace[0]]), 'level'=>'debug')
      end
    end
  end

  def rdebug_server_update(_state)
    case _state
      when RubyDebugServer::RDS_QUIET
        @rdc.kill if @rdc
        #p "@rdc.is_alive?=#{@rdc.is_alive?}"
        #p "rdebug_server_update -> Thread.current=#{Thread.current}"
        #@rdv.command_enabled(false)
        #debug_free
    end
  end

  def debug_free
    self.frame.free
    self.frame(1).free
    @rdc = nil
    @rdv = nil
  end

  def debug_quit
  #p "in debug quit @rdc.is_alive?=#{@rdc.is_alive?}"
    if @rdc 
      if @rdc.is_alive?
        Thread.new{
          Arcadia.dialog(self, 
              'type'=>'ok', 
              'title' => Arcadia.text("ext.ruby_debug.d.quit_if_debug.title"), 
              'msg'=>Arcadia.text("ext.ruby_debug.d.quit_if_debug.msg"),
              'level'=>'info')
#          Tk.messageBox('icon' => 'info', 
#          						'type' => 'ok',
#        						 'title' => '(Arcadia) Debug',
#        						 'message' => "Debug in course, stop it before exit")
        }
      else
        begin
          debug_free
        rescue Exception => e
          Arcadia.console(self, 'msg'=>"debug_quit:---> "+e.to_s+ ' ' + e.backtrace[0], 'level'=>'debug')
          #Arcadia.new_debug_msg(self, "debug_quit:---> "+e.to_s)
          #@arcadia['shell'].outln("debug_quit:---> "+e.to_s )
        end
      end
    end
  end



end