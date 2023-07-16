; 
mod_sz_autogen_s 
_df_init 
  _bankjsr $f1b3, 1 
_df_pg_dflat 
  _bankjsr $d764, 1 
_fs_chdir_w 
  _bankjsr $d4df, 2 
_fs_mkdir_w 
  _bankjsr $d572, 2 
_fs_delete_w 
  _bankjsr $d4a2, 2 
_fs_close_w 
  _bankjsr $d461, 2 
_fs_get_byte_w 
  _bankjsr $d185, 2 
_fs_open_read_w 
  _bankjsr $d34d, 2 
_fs_open_write_w 
  _bankjsr $d411, 2 
_fs_put_byte_w 
  _bankjsr $d2da, 2 
_fs_dir_find_entry_w 
  _bankjsr $cfc8, 2 
_fs_dir_entry_next_w 
  _bankjsr $cffe, 2 
_fs_dir_root_start_w 
  _bankjsr $cf83, 2 
_get_byte 
  _bankjsr $cedb, 0 
_put_byte 
  _bankjsr $cef0, 0 
_gr_get_key 
  _bankjsr $df8c, 0 
_gr_put_byte 
  _bankjsr $df99, 0 
_gr_init_screen 
  _bankjsr $da59, 0 
_init_acia 
  _bankjsr $cefd, 0 
_init_cia0 
  _bankjsr $ce88, 0 
_init_cia1 
  _bankjsr $ceb9, 0 
_init_fs 
  _bankjsr $ce60, 2 
_init_sdcard 
  _bankjsr $cb5a, 2 
_init_snd 
  _bankjsr $d2bc, 0 
_init_keyboard 
  _bankjsr $cf0f, 0 
_kb_read_raw 
  _bankjsr $cf1e, 0 
_kb_read_dip 
  _bankjsr $cf89, 0 
_command_line 
  _bankjsr $cb5a, 0 
_gr_cls 
  _bankjsr $da6c, 0 
_gr_init_hires 
  _bankjsr $da16, 0 
_gr_line 
  _bankjsr $ddc6, 0 
_gr_box 
  _bankjsr $dc06, 0 
_gr_circle 
  _bankjsr $dd11, 0 
_gr_plot 
  _bankjsr $dad7, 0 
_gr_hchar 
  _bankjsr $db15, 0 
_gr_point 
  _bankjsr $dbbb, 0 
_gr_get 
  _bankjsr $daf2, 0 
_gr_set_cur 
  _bankjsr $dafa, 0 
_snd_get_note 
  _bankjsr $d2b5, 0 
_snd_get_joy0 
  _bankjsr $c67d, 0 
_snd_set 
  _bankjsr $c625, 0 
_vdp_peek 
  _bankjsr $c61c, 0 
_vdp_poke 
  _bankjsr $c610, 0 
_vdp_init 
  _bankjsr $d800, 0 
_rtc_init 
  _bankjsr $d0df, 0 
_rtc_gettimedate 
  _bankjsr $d246, 0 
_rtc_setdatetime 
  _bankjsr $d197, 0 
_rtc_nvread 
  _bankjsr $d2ac, 0 
_rtc_nvwrite 
  _bankjsr $d294, 0 
_fs_dir_fhandle_str 
  _bankjsr $d586, 2 
_sd_sendcmd17 
  _bankjsr $cd32, 2 
_sd_sendcmd24 
  _bankjsr $cdab, 2 
mod_sz_autogen_e 
