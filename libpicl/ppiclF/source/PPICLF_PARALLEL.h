#include "PPICLF_USER.h"
#include "PPICLF_STD.h"
c Communication
      COMMON /PPICLF_PARALLEL_COMM_I/ PPICLF_COMM, PPICLF_NP, PPICLF_NID
     >                               ,PPICLF_CR_HNDL, PPICLF_FP_HNDL
     >                               ,PPICLF_COMM_NID
      INTEGER*4 PPICLF_COMM, PPICLF_NP, PPICLF_NID, PPICLF_CR_HNDL
     >         ,PPICLF_FP_HNDL, PPICLF_COMM_NID
      DATA PPICLF_NID /0/

c Bins
      INTEGER*4 PPICLF_N_BINS(3) 
      COMMON /PPICLF_PARALLEL_BIN_GLOBAL_N/ PPICLF_N_BINS

      REAL*8 PPICLF_BINS_DX(3), PPICLF_BINB(6)
      COMMON /PPICLF_PARALLEL_BIN_GLOBAL_R/ PPICLF_BINS_DX, PPICLF_BINB

      REAL*8 PPICLF_BINX(2,PPICLF_BMAX), PPICLF_BINY(2,PPICLF_BMAX)
     >    ,PPICLF_BINZ(2,PPICLF_BMAX), PPICLF_RDX, PPICLF_RDY
     >    ,PPICLF_RDZ

      REAL*4 PPICLF_GRID_X(PPICLF_BX1,PPICLF_BY1,PPICLF_BZ1)
     > ,PPICLF_GRID_Y(PPICLF_BX1,PPICLF_BY1,PPICLF_BZ1)
     > ,PPICLF_GRID_Z(PPICLF_BX1,PPICLF_BY1,PPICLF_BZ1)
     > ,PPICLF_GRID_FLD(PPICLF_BX1,PPICLF_BY1,PPICLF_BZ1,PPICLF_LRP_PRO)
      COMMON /PPICLF_PARALLEL_BIN_LOCAL_R/ PPICLF_BINX, PPICLF_BINY
     >                                    ,PPICLF_BINZ, PPICLF_RDX
     >                                    ,PPICLF_RDY, PPICLF_RDZ
     >                                    ,PPICLF_GRID_X,PPICLF_GRID_Y
     >                                    ,PPICLF_GRID_Z,PPICLF_GRID_FLD

      INTEGER*4 PPICLF_GRID_I (PPICLF_BX1, PPICLF_BY1, PPICLF_BZ1)
      COMMON /PPICLF_PARALLEL_BIN_LOCAL_I/ PPICLF_GRID_I

      INTEGER*4 PPICLF_BX, PPICLF_BY, PPICLF_BZ
      COMMON /PPICLF_PARALLEL_BIN_LOCAL_N/ PPICLF_BX, PPICLF_BY
     >                                    ,PPICLF_BZ

C Ghost particles
      REAL*8 PPICLF_RPROP_GP(PPICLF_LRP_GP,PPICLF_LPART_GP)  
     >    ,PPICLF_CP_MAP(PPICLF_LRP_GP,PPICLF_LPART)
      COMMON /PPICLF_PARALLEL_GHOST_R/ PPICLF_RPROP_GP, PPICLF_CP_MAP

      INTEGER*4 PPICLF_NB_R(3,PPICLF_LPART)
     >         ,PPICLF_NB_G(3,PPICLF_LPART_GP)
      COMMON /PPICLF_PARALLEL_NEIGHBOR_I/ PPICLF_NB_R, PPICLF_NB_G

      INTEGER*4 PPICLF_IPROP_GP(PPICLF_LIP_GP,PPICLF_LPART_GP)
      COMMON /PPICLF_PARALLEL_GHOST_I/ PPICLF_IPROP_GP

      INTEGER*4  PPICLF_NPART_GP
      COMMON /PPICLF_PARALLEL_GHOST_N/ PPICLF_NPART_GP
