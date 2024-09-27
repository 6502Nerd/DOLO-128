; 
mod_sz_autogen_s 
_df_init 
  _bankjsr $f1da, 1 
_df_pg_dflat 
  _bankjsr $d781, 1 
_fs_chdir_w 
  _bankjsr $d511, 2 
_fs_mkdir_w 
  _bankjsr $d5a4, 2 
_fs_delete_w 
  _bankjsr $d4ad, 2 
_fs_close_w 
  _bankjsr $d46c, 2 
_fs_get_byte_w 
  _bankjsr $d189, 2 
_fs_open_read_w 
  _bankjsr $d358, 2 
_fs_open_write_w 
  _bankjsr $d41c, 2 
_fs_put_byte_w 
  _bankjsr $d2e5, 2 
_fs_dir_find_entry_w 
  _bankjsr $cfcc, 2 
_fs_dir_entry_next_w 
  _bankjsr $d002, 2 
_fs_dir_root_start_w 
  _bankjsr $cf87, 2 
_get_byte 
  _bankjsr $d1d1, 0 
_put_byte 
  _bankjsr $d1e6, 0 
_gr_get_key 
<<<<<<< HEAD
  _bankjsr $e28c, 0 
_gr_put_byte 
  _bankjsr $e299, 0 
=======
  _bankjsr $df90, 0 
_gr_put_byte 
  _bankjsr $df9d, 0 
>>>>>>> 17e390f07d4b2c6af368e42796b6bdaed80a3e2e
_gr_init_screen 
  _bankjsr $dd59, 0 
_init_acia 
  _bankjsr $d1f3, 0 
_init_cia0 
  _bankjsr $d17e, 0 
_init_cia1 
  _bankjsr $d1af, 0 
_init_fs 
  _bankjsr $ce64, 2 
_init_sdcard 
  _bankjsr $cb5e, 2 
_init_snd 
  _bankjsr $d5bc, 0 
_init_keyboard 
  _bankjsr $d205, 0 
_kb_read_raw 
  _bankjsr $d214, 0 
_kb_read_dip 
  _bankjsr $d27f, 0 
_command_line 
  _bankjsr $cb5e, 0 
_gr_cls 
  _bankjsr $dd6c, 0 
_gr_init_hires 
  _bankjsr $dd16, 0 
_gr_line 
<<<<<<< HEAD
  _bankjsr $e0c6, 0 
_gr_box 
  _bankjsr $df06, 0 
_gr_circle 
  _bankjsr $e011, 0 
=======
  _bankjsr $ddca, 0 
_gr_box 
  _bankjsr $dc0a, 0 
_gr_circle 
  _bankjsr $dd15, 0 
>>>>>>> 17e390f07d4b2c6af368e42796b6bdaed80a3e2e
_gr_plot 
  _bankjsr $ddd7, 0 
_gr_hchar 
  _bankjsr $de15, 0 
_gr_point 
  _bankjsr $debb, 0 
_gr_get 
  _bankjsr $ddf2, 0 
_gr_set_cur 
  _bankjsr $ddfa, 0 
_snd_get_note 
  _bankjsr $d5b5, 0 
_snd_get_joy0 
  _bankjsr $c695, 0 
_snd_set 
  _bankjsr $c63d, 0 
_vdp_peek 
  _bankjsr $c634, 0 
_vdp_poke 
  _bankjsr $c628, 0 
_vdp_init 
  _bankjsr $db00, 0 
_rtc_init 
  _bankjsr $d3db, 0 
_rtc_gettimedate 
  _bankjsr $d541, 0 
_rtc_setdatetime 
  _bankjsr $d492, 0 
_rtc_nvread 
  _bankjsr $d5ac, 0 
_rtc_nvwrite 
  _bankjsr $d594, 0 
_fs_dir_fhandle_str 
  _bankjsr $d5b8, 2 
_sd_sendcmd17 
  _bankjsr $cd36, 2 
_sd_sendcmd24 
  _bankjsr $cdaf, 2 
_cmd_immediate 
  _bankjsr $cb6a, 0 
mod_sz_autogen_e 
