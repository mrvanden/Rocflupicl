










!*********************************************************************
!* Illinois Open Source License                                      *
!*                                                                   *
!* University of Illinois/NCSA                                       * 
!* Open Source License                                               *
!*                                                                   *
!* Copyright@2008, University of Illinois.  All rights reserved.     *
!*                                                                   *
!*  Developed by:                                                    *
!*                                                                   *
!*     Center for Simulation of Advanced Rockets                     *
!*                                                                   *
!*     University of Illinois                                        *
!*                                                                   *
!*     www.csar.uiuc.edu                                             *
!*                                                                   *
!* Permission is hereby granted, free of charge, to any person       *
!* obtaining a copy of this software and associated documentation    *
!* files (the "Software"), to deal with the Software without         *
!* restriction, including without limitation the rights to use,      *
!* copy, modify, merge, publish, distribute, sublicense, and/or      *
!* sell copies of the Software, and to permit persons to whom the    *
!* Software is furnished to do so, subject to the following          *
!* conditions:                                                       *
!*                                                                   *
!*                                                                   *
!* @ Redistributions of source code must retain the above copyright  * 
!*   notice, this list of conditions and the following disclaimers.  *
!*                                                                   * 
!* @ Redistributions in binary form must reproduce the above         *
!*   copyright notice, this list of conditions and the following     *
!*   disclaimers in the documentation and/or other materials         *
!*   provided with the distribution.                                 *
!*                                                                   *
!* @ Neither the names of the Center for Simulation of Advanced      *
!*   Rockets, the University of Illinois, nor the names of its       *
!*   contributors may be used to endorse or promote products derived * 
!*   from this Software without specific prior written permission.   *
!*                                                                   *
!* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,   *
!* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES   *
!* OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND          *
!* NONINFRINGEMENT.  IN NO EVENT SHALL THE CONTRIBUTORS OR           *
!* COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       * 
!* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   *
!* ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE    *
!* USE OR OTHER DEALINGS WITH THE SOFTWARE.                          *
!*********************************************************************
!* Please acknowledge The University of Illinois Center for          *
!* Simulation of Advanced Rockets in works and publications          *
!* resulting from this software or its derivatives.                  *
!*********************************************************************
! ******************************************************************************
!
! Purpose: Driver routine for rflumap. 
!
! Description: None.
!
! Input: 
!   caseString  String with casename
!   mapOption   Mapping mode
!   nRegions    Number of regions
!   nProcs      Number of processes
!   verbLevel   Verbosity level
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
!
! $Id: rflumap.F90,v 1.1.1.1 2015/01/23 22:57:50 tbanerjee Exp $
!
! Copyright: (c) 2002-2005 by the University of Illinois
!
! ******************************************************************************

SUBROUTINE rflumap(caseString,mapOption,nRegions,nProcs,verbLevel)

  USE ModDataTypes
  USE ModParameters
  USE ModError
  USE ModGlobal, ONLY: t_global
  USE ModDataStruct, ONLY: t_level,t_region 
  
  USE RFLU_ModDimensions
  USE RFLU_ModRegionMapping
  
  
  USE ModInterfaces, ONLY: RFLU_BuildDataStruct, &
                           RFLU_CreateGrid, &
                           RFLU_DestroyGrid, &
                           RFLU_GetUserInput, & 
                           RFLU_InitGlobal, & 
                           RFLU_PrintHeader, & 
                           RFLU_PrintWarnInfo, &
                           RFLU_ReadRestartInfo, & 
                           RFLU_SetRestartTimeFlag, & 
                           RFLU_WriteVersionString
  
  IMPLICIT NONE
  
! ******************************************************************************
! Definitions and declarations
! ******************************************************************************

! ==============================================================================
! Arguments
! ==============================================================================

  CHARACTER(*) :: caseString
  INTEGER, INTENT(IN) :: nProcs,nRegions,mapOption,verbLevel

! ==============================================================================
! Locals
! ==============================================================================

  CHARACTER(CHRLEN) :: casename,paneStringSurf,paneStringVol,RCSIdentString
  INTEGER, PARAMETER :: MAP_INITIAL = 1, & 
                        MAP_FINAL   = 2
  INTEGER :: errorFlag,iFile,iReg,iProc,nRegionsLocal
  TYPE(t_global), POINTER :: global
  TYPE(t_level), POINTER :: levels(:) 
  TYPE(t_region), POINTER :: pRegion 

! ******************************************************************************
! Start
! ******************************************************************************

  RCSIdentString = '$RCSfile: rflumap.F90,v $ $Revision: 1.1.1.1 $'
  
! ******************************************************************************
! Initialize global data
! ******************************************************************************  
  
  ALLOCATE(global,STAT=errorFlag)
  IF ( errorFlag /= ERR_NONE ) THEN 
    WRITE(STDERR,'(A,1X,A)') SOLVER_NAME,'ERROR - Pointer allocation failed.'
    STOP
  END IF ! errorFlag 

  casename = caseString(1:LEN(caseString))
    
  CALL RFLU_InitGlobal(casename,verbLevel,CRAZY_VALUE_INT,global)


! ******************************************************************************
! Print header
! ******************************************************************************

  CALL RFLU_PrintHeader(global)
  CALL RFLU_WriteVersionString(global) 
                                  
! ******************************************************************************
! Build region-to-process mapping and write mapping to file
! ******************************************************************************
    
! ==============================================================================
! Initial mapping
! ==============================================================================

  IF ( mapOption == MAP_INITIAL ) THEN 
    global%nRegions = nRegions
    global%nProcs   = nProcs
    
    CALL RFLU_CreateRegionMapping(global,MAPTYPE_PROC2REG)
    CALL RFLU_BuildRegionMappingSimple(global)
    CALL RFLU_CheckRegionMapping(global)
    CALL RFLU_OpenRegionMappingFile(global)
    CALL RFLU_WriteRegionMappingFile(global)
    CALL RFLU_CloseRegionMappingFile(global)
    CALL RFLU_DestroyRegionMapping(global,MAPTYPE_PROC2REG)

! ==============================================================================
! Final mapping
! ==============================================================================

  ELSE IF ( mapOption == MAP_FINAL ) THEN
    CALL RFLU_ReadRegionMappingFile(global,MAPFILE_READMODE_PEEK,-1)
    
    
! ------------------------------------------------------------------------------
!   Loop over processes
! ------------------------------------------------------------------------------    
    
    DO iProc = 1,global%nProcs
      CALL RFLU_CreateRegionMapping(global,MAPTYPE_REG)
      CALL RFLU_ReadRegionMappingFile(global,MAPFILE_READMODE_ALL,iProc-1)
    
      CALL RFLU_BuildDataStruct(global,levels)
      CALL RFLU_ApplyRegionMapping(global,levels)

      CALL RFLU_GetUserInput(levels(1)%regions)      
      CALL RFLU_ReadRestartInfo(global)
      CALL RFLU_SetRestartTimeFlag(global)      

! --- Loop over regions -------------------------------------------------------- 
                 
      paneStringVol  = ''           
      paneStringSurf = ''           
                  
      DO iReg = 1,global%nRegionsLocal
        pRegion => levels(1)%regions(iReg)
    
        CALL RFLU_ReadDimensions(pRegion)
        CALL RFLU_CreateGrid(pRegion)

        
        CALL RFLU_DestroyGrid(pRegion)
      END DO ! iReg                            
                 

      CALL RFLU_DestroyRegionMapping(global,MAPTYPE_REG)
    END DO ! iProc        
            

! ==============================================================================
! Invalid mapping option
! ==============================================================================
  
  ELSE 
    CALL ErrorStop(global,ERR_REACHED_DEFAULT,246)  
  END IF ! mapOption

! ******************************************************************************
! Print info about warnings
! ******************************************************************************
  
  CALL RFLU_PrintWarnInfo(global)

! ******************************************************************************
! End
! ******************************************************************************

END SUBROUTINE rflumap

! ******************************************************************************
!
! RCS Revision history:
!
! $Log: rflumap.F90,v $
! Revision 1.1.1.1  2015/01/23 22:57:50  tbanerjee
! merged rocflu micro and macro
!
! Revision 1.1.1.1  2014/07/15 14:31:37  brollin
! New Stable version
!
! Revision 1.3  2008/12/06 08:43:56  mtcampbe
! Updated license.
!
! Revision 1.2  2008/11/19 22:17:10  mtcampbe
! Added Illinois Open Source License/Copyright
!
! Revision 1.1  2007/04/09 18:56:21  haselbac
! Initial revision after split from RocfloMP
!
! Revision 1.4  2006/04/07 15:19:25  haselbac
! Removed tabs
!
! Revision 1.3  2006/02/06 23:55:55  haselbac
! Added comm argument to RFLU_InitGlobal
!
! Revision 1.2  2005/05/03 03:11:01  haselbac
! Converted to C++ reading of command-line
!
! Revision 1.1  2005/04/18 14:57:56  haselbac
! Initial revision
!
! ******************************************************************************

