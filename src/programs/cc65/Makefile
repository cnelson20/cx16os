all: cx16os.lib cx16os_bonk.lib

AS = ca65

C_CONFIG = cx16os_c.cfg
A_FLAGS = -t none --cpu 65816

OBJS := $(patsubst %.s,%.o,$(wildcard *.s))

INCS = routines.inc time.inc

stripped.lib: supervision.lib
	cp supervision.lib stripped.lib
	ar65 d stripped.lib joy-kernel.o joy_count.o joy_load.o joy_read.o joy_stat_stddrv.o joy_unload.o
	ar65 d stripped.lib tgi_arc.o tgi_bar.o tgi_circle.o tgi_clear.o tgi_clippedline.o tgi_colors.o tgi_curtoxy.o tgi_done.o tgi_ellipse.o tgi_free_vectorfont.o tgi_getaspectratio.o tgi_getcolor.o tgi_getcolorcount.o tgi_getdefpalette.o tgi_geterror.o tgi_geterrormsg.o tgi_getmaxcolor.o tgi_getmaxx.o tgi_getmaxy.o tgi_getpagecount.o tgi_getpalette.o tgi_getpixel.o tgi_getset.o tgi_gettextheight.o tgi_gettextwidth.o tgi_getxres.o tgi_getyres.o tgi_gotoxy.o tgi_imulround.o tgi_init.o tgi_install_vectorfont.o tgi_ioctl.o tgi_line.o tgi_linepop.o tgi_lineto.o tgi_load.o tgi_load_vectorfont.o tgi_outcode.o tgi_outtext.o tgi_outtextxy.o tgi_pieslice.o tgi_popxy.o tgi_popxy2.o tgi_setaspectratio.o tgi_setcolor.o tgi_setdrawpage.o tgi_setpalette.o tgi_setpixel.o tgi_settextdir.o tgi_settextstyle.o tgi_setviewpage.o tgi_unload.o tgi_vectorchar.o

cx16os.lib: stripped.lib $(C_CONFIG) $(OBJS)
	cp stripped.lib $@
	rm -f crt0_bonk.o
	ar65 a $@ *.o

cx16os_bonk.lib: cx16os.lib $(C_BONK_CONFIG) crt0_bonk.o
	cp cx16os.lib $@
	ar65 d $@ crt0.o
	ar65 a $@ crt0_bonk.o
	
$(OBJS): %.o: %.s $(INCS)
	$(AS) $(A_FLAGS) $<

crt0_bonk.o: crt0.s $(INCS)
	$(AS) $(A_FLAGS) -o $@ -D __BONK_DEFINE__ crt0.s

clean:
	rm -f *.o
	
clear:
	rm -f cx16os.lib
