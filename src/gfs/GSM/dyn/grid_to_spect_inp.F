      subroutine grid_to_spect_inp(zsg,psg,uug,vvg,ttg,rqg,dpg
     &,                            trie_ls,trio_ls
     &,                            ls_node,ls_nodes,max_ls_nodes
     &,                            lats_nodes_a,global_lats_a,lonsperlat
     &,                            epse,epso,plnew_a,plnow_a
     &,                            plnev_a,plnod_a,pwat,ptot,ptrc)
!    &                             pwat,ptot,ptrc,slg_flag)
!!
!! hmhj - this routine do grid to spectral transform 
!!        from nemsio read in field, to model fields
!! input zsg,psg,uug,vvg,ttg,rqg (mapping wind, temp)
!! output zsg,psg,uug,vvg,ttg,rqg in model values (mapping wind, enthalpy)
!! aug 2010      sarah lu, modified to compute tracer global sum
!! feb 2011      henry juang updated to fit mass_dp and ndslfv
!! feb 2015      Jun Wang  add option for slg_flag
!! oct 2015      s moorthi remove option  slg_flag
!!
      use gfs_dyn_resol_def
      use gfs_dyn_layout1
      use gfs_dyn_gg_def
      use gfs_dyn_vert_def
      use gfs_dyn_date_def
      use namelist_dynamics_def
      use gfs_dyn_coordinate_def 
      use gfs_dyn_tracer_const
      use gfs_dyn_tracer_config, only: glbsum                     !glbsum
      use gfs_dyn_physcons, fv => con_fvirt, rerth => con_rerth,
     &              grav => con_g,  cp => con_cp , rd => con_rd
      implicit none
!!
      real(kind=kind_grid) zsg(lonf,lats_node_a)
      real(kind=kind_grid) psg(lonf,lats_node_a)
      real(kind=kind_grid) uug(lonf,lats_node_a,levs)
      real(kind=kind_grid) vvg(lonf,lats_node_a,levs)
      real(kind=kind_grid) ttg(lonf,lats_node_a,levs)
      real(kind=kind_grid) rqg(lonf,lats_node_a,levh)
      real(kind=kind_grid) dpg(lonf,lats_node_a,levs)
!
      REAL(KIND=KIND_GRID) pwat   (lonf,lats_node_a)
      REAL(KIND=KIND_GRID) ptot   (lonf,lats_node_a)
      REAL(KIND=KIND_GRID) ptrc   (lonf,lats_node_a,ntrac)        !glbsum
      REAL(KIND=KIND_GRID) work   (lonf)
      REAL(KIND=KIND_GRID) tki    (lonf,levp1)
      REAL(KIND=KIND_GRID) prsi   (lonf,levp1)

      real(kind=kind_evod)  tkrt0
      real(kind=kind_evod), parameter :: rkappa = cp / rd
!     logical               slg_flag
!
      real(kind=kind_evod) trie_ls(len_trie_ls,2,lotls)
      real(kind=kind_evod) trio_ls(len_trio_ls,2,lotls)
!!
      real(kind=kind_evod) for_gr_a_1(lonfx*(lota+1),lats_dim_a)
      real(kind=kind_evod) for_gr_a_2(lonfx*(lota+1),lats_dim_a)
!
      integer              ls_node(ls_dim,3)
      integer              ls_nodes(ls_dim,nodes)
      integer              max_ls_nodes(nodes)
      integer              lats_nodes_a(nodes)
      integer              global_lats_a(latg)
      integer                 lonsperlat(latg)
      integer dimg
!
      real(kind=kind_evod)  epse(len_trie_ls)
      real(kind=kind_evod)  epso(len_trio_ls)
!
      real(kind=kind_evod)   plnew_a(len_trie_ls,latg2)
      real(kind=kind_evod)   plnow_a(len_trio_ls,latg2)
      real(kind=kind_evod)   plnev_a(len_trie_ls,latg2)
      real(kind=kind_evod)   plnod_a(len_trio_ls,latg2)
!
      real(kind=kind_evod)   tfac(lonf,levs), sumq(lonf,levs), rcs2
!
      integer              i,j,k,kk, nn, nnl
      integer              l,lan,lat,lotdim,lotx
      integer              lon_dim,lons_lat
!
      integer              locl,n
      integer              indev
      integer              indod
      integer              indev1,indev2
      integer              indod1,indod2
      INTEGER              INDLSEV,JBASEV
      INTEGER              INDLSOD,JBASOD
!

      real(kind=kind_evod), parameter :: one=1.0, pa2cb=0.001
!
!timers______________________________________________________---
      real*8 rtc ,timer1,timer2
!timers______________________________________________________---
!
!
      real(kind=kind_evod), parameter :: cons_0=0.0,   cons_24=24.0
     &,                                  cons_99=99.0, cons_1p0d9=1.0E9
     &,                                  qmin=1.0e-10
!
      real(kind=kind_evod) ga2, tem
!
      INCLUDE 'function2'
!
!--------------------------------------------------------------------
!
      lotdim  = lota + 1
      if( ndslfv ) then
        lotx    = 4*levs+ 1 + 1
      else
!       if(.not.slg_flag) then
          lotx    = 4*levs+levh+1 + 1
!       else   !slg no dp
!         lotx    = 3*levs+levh+1 + 1
!       endif
      endif
!
!--------------------------------------------------------------------
      do lan=1,lats_node_a
        lon_dim  = lon_dims_a(lan)
        lat      = global_lats_a(ipt_lats_node_a-1+lan)
        lons_lat = lonsperlat(lat)
        rcs2     = rcs2_a(min(lat,latg-lat+1))
!
        if (thermodyn_id == 3) then
          do k=1,levs
            do i=1,lons_lat
              tfac(i,k) = 0.0
              sumq(i,k) = 0.0
            enddo
          enddo

          do nn=1,ntrac
            nnl = (nn-1)*levs
            if (cpi(nn) .ne. 0.0) then
              do k=1,levs
                do i=1,lons_lat
                  sumq(i,k) = sumq(i,k) + rqg(i,lan,nnl+k)
                  tfac(i,k) = tfac(i,k) + cpi(nn)*rqg(i,lan,nnl+k)
                enddo
              enddo
            endif

          enddo

          do k=1,levs
            do i=1,lons_lat
              tfac(i,k) = (one-sumq(i,k))*cpi(0) + tfac(i,k)
            enddo
          enddo
        else
          do k=1,levs
            do i=1,lons_lat
              tfac(i,k) = one + fv*max(rqg(i,lan,k),qmin) 
            enddo
          enddo
        endif
        do k=1,levs
          do i=1,lons_lat
            uug(i,lan,k) = uug(i,lan,k) * coslat_a(lat)
            vvg(i,lan,k) = vvg(i,lan,k) * coslat_a(lat)
            ttg(i,lan,k) = ttg(i,lan,k) * tfac(i,k)
            for_gr_a_2(i+(kat+k-2)*lon_dim,lan) = ttg(i,lan,k)
            for_gr_a_2(i+(kau+k-2)*lon_dim,lan) = uug(i,lan,k) * rcs2
            for_gr_a_2(i+(kav+k-2)*lon_dim,lan) = vvg(i,lan,k) * rcs2
          enddo
        enddo

        if( .not. ndslfv ) then
          do k=1,levh
            do i=1,lons_lat
              for_gr_a_2(i+(kar+k-2)*lon_dim,lan)=rqg(i,lan,k)
            enddo
          enddo
        endif
        do i=1,lons_lat
          ptot(i,lan) = psg(i,lan) * pa2cb
        enddo
        if (gen_coord_hybrid) then   ! Ps is the prognostic variable
          do i=1,lons_lat
            psg(i,lan) = psg(i,lan) * pa2cb
          enddo
        else                         ! ln(Ps) is the prognostic variable
          do i=1,lons_lat
            psg(i,lan) = log(psg(i,lan)*pa2cb)
          enddo
        endif
        do i=1,lons_lat
          for_gr_a_2(i+(kazs-1)*lon_dim,lan) = zsg(i,lan)
          for_gr_a_2(i+(kaps-1)*lon_dim,lan) = psg(i,lan)
        enddo
!
! get pressure at interfaces for pwat 
        if (gen_coord_hybrid) then  
          tki = 0.0
          do k=2,levs
            do i=1,lons_lat
              tkrt0 = (ttg(i,lan,k-1)+ttg(i,lan,k))
     &                           /(thref(k-1)+thref(k))
              tki (i,k)=ck5(k)*tkrt0**rkappa
            enddo
          enddo
          do k=1,levp1
            do i=1,lons_lat
              prsi(i,k)  = ak5(k)+bk5(k)*psg(i,lan)+tki(i,k) 
            enddo
          enddo
        else if( hybrid ) then
          do k=1,levp1
            kk=levp1+1-k
            do i=1,lons_lat
              prsi(i,k)  = ak5(kk)+bk5(kk)*ptot(i,lan)
            enddo
          enddo
        else
          do k=1,levp1
            do i=1,lons_lat
              prsi(i,k)  = si(k)*ptot(i,lan)
            enddo
          enddo
        endif                      
!
! get pwat (total vertical integrated water)
        do i=1,lons_lat
          pwat(i,lan) = 0.0
        enddo
        do k=1,levs
          do i=1,lons_lat
            work(i) = 0.0
          enddo
          if( ncld > 0 ) then
            do nn=ntcw,ntcw+ncld-1
              nnl = (nn-1)*levs
              do i=1,lons_lat
                work(i) = work(i) + rqg(i,lan,nnl+k)
              enddo
            enddo
          endif
          do i=1,lons_lat
! use definition for dpg instead of read in to have more accurate
! definition by th coordinates
!          if (.not.slg_flag) then
            dpg (i,lan,k) = prsi(i,k)-prsi(i,k+1)
            pwat(i,lan)   = pwat(i,lan) + dpg(i,lan,k)
     &                                  * (rqg(i,lan,k) + work(i))
!          endif
          enddo
        enddo
!       if (.not.slg_flag) then
          do k=1,levs
            do i=1,lons_lat
              for_gr_a_2(i+(kadp+k-2)*lon_dim,lan) = dpg(i,lan,k)
            enddo
          enddo
          if( me==0 ) then
            print *,' dpg in grid_to_spect_inp ',(dpg(1,lan,k),k=1,levs)
          endif
!       endif

!
! compute ptrc (tracer global sum)                               !glbsum
!
        if( glbsum ) then                                        !glbsum
          do nn = 1, ntrac                                       !glbsum
            nnl = (nn-1)*levs                                    !glbsum
            do i=1,lons_lat                                      !glbsum
             ptrc(i,lan,nn) = 0.0                                !glbsum
             do k=1,levs                                         !glbsum
               ptrc(i,lan,nn) = ptrc(i,lan,nn) +                 !glbsum
     &         (prsi(i,k)-prsi(i,k+1))*rqg(i,lan,nnl+k)          !glbsum
             enddo                                               !glbsum
            enddo                                                !glbsum
          enddo                                                  !glbsum
        endif                                                    !glbsum

!
      enddo
!
! =======================================================================
      do lan=1,lats_node_a
!
         lon_dim = lon_dims_a(lan)
!
         lat = global_lats_a(ipt_lats_node_a-1+lan)
         lons_lat = lonsperlat(lat)

         call grid2four_thread(for_gr_a_2(1,lan),for_gr_a_1(1,lan),
     &                  lon_dim,lons_lat,lonfx,lotx)
!
      enddo
!
      dimg=0
      call four2fln(lats_dim_a,lotdim,lotx,for_gr_a_1,
     &              ls_nodes,max_ls_nodes,
     &              lats_nodes_a,global_lats_a,lon_dims_a,
     &              lats_node_a,ipt_lats_node_a,dimg,
     &              lat1s_a,lonfx,latg,latg2,
     &              trie_ls(1,1,p_w), trio_ls(1,1,p_w),
     &              plnew_a, plnow_a,
     &              ls_node,2*levs)
!
!$OMP parallel do shared(trie_ls,trio_ls)
!$OMP+shared(p_w,p_x,p_uln,p_vln,epse,epso,ls_node)
!$OMP+private(k)
      do k=1,levs
         call uveodz(trie_ls(1,1,P_w  +k-1), trio_ls(1,1,P_x  +k-1),
     &               trie_ls(1,1,P_uln+k-1), trio_ls(1,1,P_vln+k-1),
     &               epse,epso,ls_node)
!
         call uvoedz(trio_ls(1,1,P_w  +k-1), trie_ls(1,1,P_x  +k-1),
     &               trio_ls(1,1,P_uln+k-1), trie_ls(1,1,P_vln+k-1),
     &               epse,epso,ls_node)
      enddo
!
!   move uln back to x
!   move vln back to w
!
      do k=1,levs
         do i=1,len_trie_ls
            trie_ls(i,1,P_x +k-1) = trie_ls(i,1,P_uln +k-1)
            trie_ls(i,2,P_x +k-1) = trie_ls(i,2,P_uln +k-1)
            trie_ls(i,1,P_w +k-1) = trie_ls(i,1,P_vln +k-1)
            trie_ls(i,2,P_w +k-1) = trie_ls(i,2,P_vln +k-1)
         enddo
         do i=1,len_trio_ls
            trio_ls(i,1,P_x +k-1) = trio_ls(i,1,P_uln +k-1)
            trio_ls(i,2,P_x +k-1) = trio_ls(i,2,P_uln +k-1)
            trio_ls(i,1,P_w +k-1) = trio_ls(i,1,P_vln +k-1)
            trio_ls(i,2,P_w +k-1) = trio_ls(i,2,P_vln +k-1)
         enddo
      enddo
!
! -------------------------------------------------------------------
! model realted filter such as reduced grid spectral transform for zs
!
      if( fhour == 0.0 ) then

      dimg = 0
!
      call sumflna(trie_ls(1,1,p_gz),trio_ls(1,1,p_gz),
     x            lat1s_a,
     x            plnev_a,plnod_a,
     x            1,ls_node,latg2,
     x            lats_dim_a,lotdim,for_gr_a_1,
     x            ls_nodes,max_ls_nodes,
     x            lats_nodes_a,global_lats_a,
     x            lats_node_a,ipt_lats_node_a,lon_dims_a,dimg,
     x            lonsperlat,lonfx,latg)
 
      do lan=1,lats_node_a
cc
         lat = global_lats_a(ipt_lats_node_a-1+lan)
         lon_dim = lon_dims_a(lan)
         lons_lat = lonsperlat(lat)
cc
         call four2grid_thread(for_gr_a_1(1,lan),for_gr_a_2(1,lan),
     &                  lon_dim,lons_lat,lonfx,1,lan,me)
 
         do i=1,lons_lat
           zsg(i,lan) = for_gr_a_2(i,lan)
         enddo
      enddo   !lan
      endif   ! fhour=0.0
! -------------------------------------------------------------------
!     print *,' exit grid_to_spect_inp '
!!
      return
      end
