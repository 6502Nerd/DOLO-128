; 
mod_sz_autogen_s 
_df_init 
  _bankjsr $f19c, 1 
_df_pg_dflat 
  _bankjsr $d755, 1 
_fs_chdir_w 
  _bankjsr $d4d0, 2 
_fs_mkdir_w 
  _bankjsr $d563, 2 
_fs_delete_w 
  _bankjsr $d493, 2 
_fs_close_w 
  _bankjsr $d452, 2 
_fs_get_byte_w 
  _bankjsr $d176, 2 
_fs_open_read_w 
  _bankjsr $d33e, 2 
_fs_open_write_w 
  _bankjsr $d402, 2 
_fs_put_byte_w 
  _bankjsr $d2cb, 2 
_fs_dir_find_entry_w 
  _bankjsr $cfb9, 2 
_fs_dir_entry_next_w 
  _bankjsr $cfef, 2 
_fs_dir_root_start_w 
  _bankjsr $cf74, 2 
_get_byte 
  _bankjsr $cecc, 0 
_put_byte 
  _bankjsr $cee1, 0 
_gr_get_key 
  _bankjsr $df8c, 0 
_gr_put_byte 
  _bankjsr $df99, 0 
_gr_init_screen 
  _bankjsr $da59, 0 
_init_acia 
  _bankjsr $ceee, 0 
_init_cia0 
  _bankjsr $ce79, 0 
_init_cia1 
  _bankjsr $ceaa, 0 
_init_fs 
  _bankjsr $ce51, 2 
_init_sdcard 
  _bankjsr $cb4b, 2 
_init_snd 
  _bankjsr $d2ad, 0 
_init_keyboard 
  _bankjsr $cf00, 0 
_kb_read_raw 
  _bankjsr $cf0f, 0 
_kb_read_dip 
  _bankjsr $cf7a, 0 
_command_line 
  _bankjsr $cb4b, 0 
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
  _bankjsr $d2a6, 0 
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
  _bankjsr $d0d0, 0 
_rtc_gettimedate 
  _bankjsr $d237, 0 
_rtc_setdatetime 
  _bankjsr $d188, 0 
_rtc_nvread 
  _bankjsr $d29d, 0 
_rtc_nvwrite 
  _bankjsr $d285, 0 
_fs_dir_fhandle_str 
  _bankjsr $d577, 2 
_sd_sendcmd17 
  _bankjsr $cd23, 2 
_sd_sendcmd24 
  _bankjsr $cd9c, 2 
mod_sz_autogen_e 
