      module vert_def
      use machine, ONLY: KIND_EVOD
      implicit none

      REAL(KIND=KIND_EVOD) ,ALLOCATABLE :: am(:,:),bm(:,:),cm(:,:),
     . dm(:,:,:),tor(:), si(:),sl(:),del(:),rdel2(:),ci(:),
     . cl(:),tov(:),sv(:)
      real(kind=kind_evod), allocatable :: slk(:), sik(:)
      end module vert_def
