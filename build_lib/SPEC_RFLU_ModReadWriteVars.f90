










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
! Purpose: Suite of routines to read and write species solution files.
!
! Description: None.
!
! Notes: None.
!
! ******************************************************************************
!
! $Id: SPEC_RFLU_ModReadWriteVars.F90,v 1.2 2015/07/23 23:11:19 brollin Exp $
!
! Copyright: (c) 2005 by the University of Illinois
!
! ******************************************************************************

MODULE SPEC_RFLU_ModReadWriteVars

  USE ModParameters
  USE ModDataTypes
  USE ModError
  USE ModGlobal, ONLY: t_global
  USE ModBndPatch, ONLY: t_patch
  USE ModDataStruct, ONLY: t_region
  USE ModGrid, ONLY: t_grid
  USE ModMPI

  USE ModBuildFileNames, ONLY: BuildFileNameSteady, &
                               BuildFileNameUnsteady

  USE SPEC_ModParameters

  IMPLICIT NONE

  PRIVATE
  PUBLIC :: SPEC_RFLU_ReadCvASCII, & 
            SPEC_RFLU_ReadCvBinary, & 
            SPEC_RFLU_ReadEEvASCII, & 
            SPEC_RFLU_ReadEEvBinary, & 
            SPEC_RFLU_WriteCvASCII, & 
            SPEC_RFLU_WriteCvBinary, & 
            SPEC_RFLU_WriteEEvASCII, & 
            SPEC_RFLU_WriteEEvBinary            
                        

! ******************************************************************************
! Declarations and definitions
! ******************************************************************************

  CHARACTER(CHRLEN) :: RCSIdentString = &
    '$RCSfile: SPEC_RFLU_ModReadWriteVars.F90,v $ $Revision: 1.2 $'

! ******************************************************************************
! Routines
! ******************************************************************************

  CONTAINS







! ******************************************************************************
!
! Purpose: Read flow file for species in ASCII ROCFLU format.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes:
!   1. Read physical time for both steady and unsteady flows so that could 
!      use steady solution as input for unsteady run and vice versa.
!   2. For GENX runs, read file from time zero if restarting. This is for 
!      convenience and will have to be changed once grid adaptation is used.
!
! ******************************************************************************

SUBROUTINE SPEC_RFLU_ReadCvASCII(pRegion)

  IMPLICIT NONE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
   
! ==============================================================================
! Local variables
! ==============================================================================

  LOGICAL :: fileExists
  CHARACTER(CHRLEN) :: errorString,iFileName,iFileNameOld,sectionString, &
                       timeString1,timeString2
  INTEGER :: errorFlag,i,iFile,iVars,j,loopCounter,nCellsTot,nCellsExpected, & 
             nVars,nVarsExpected,precActual,precExpected,rangeActual, & 
             rangeExpected
  REAL(RFREAL) :: currentTime
  REAL(RFREAL), DIMENSION(:,:), POINTER :: pCv
  TYPE(t_grid), POINTER :: pGrid
  TYPE(t_global), POINTER :: global
  
! ==============================================================================
! Arguments
! ==============================================================================

  TYPE(t_region), POINTER :: pRegion  
  
! ******************************************************************************
! Start, open file
! ******************************************************************************

  global => pRegion%global

  CALL RegisterFunction(global,'SPEC_RFLU_ReadCvASCII',"../rocspecies/SPEC_RFLU_ModReadWriteVars.F90")

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_NONE ) THEN 
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Reading ASCII species cv file...'
  END IF ! global%verbLevel

  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    CALL BuildFileNameUnsteady(global,FILEDEST_INDIR,'.spec.cva', & 
                               pRegion%iRegionGlobal,global%currentTime, &
                               iFileName)
    CALL BuildFileNameUnsteady(global,FILEDEST_INDIR,'.spca', & 
                               pRegion%iRegionGlobal,global%currentTime, &
                               iFileNameOld)                               
  ELSE
    CALL BuildFileNameSteady(global,FILEDEST_INDIR,'.spec.cva', & 
                             pRegion%iRegionGlobal,global%currentIter, &
                             iFileName)
    CALL BuildFileNameSteady(global,FILEDEST_INDIR,'.spca', & 
                             pRegion%iRegionGlobal,global%currentIter, &
                             iFileNameOld)                               
  END IF ! global%flowType

  iFile = IF_SOLUT

  INQUIRE(FILE=iFileName,EXIST=fileExists)

  IF ( fileExists .EQV. .TRUE. ) THEN 
    OPEN(iFile,FILE=iFileName,FORM="FORMATTED",STATUS="OLD",IOSTAT=errorFlag)
    global%error = errorFlag
    IF ( global%error /= ERR_NONE ) THEN
      CALL ErrorStop(global,ERR_FILE_OPEN,202,iFileName)
    END IF ! global%error
  ELSE 
    OPEN(iFile,FILE=iFileNameOld,FORM="FORMATTED",STATUS="OLD",IOSTAT=errorFlag)
    global%error = errorFlag
    IF ( global%error /= ERR_NONE ) THEN
      CALL ErrorStop(global,ERR_FILE_OPEN,208,iFileNameOld)
    END IF ! global%error    
  END IF ! fileExists

! ==============================================================================
! Set state vector state: Solution always stored in conservative form
! ==============================================================================

  pRegion%spec%cvState = CV_MIXT_STATE_CONS

! ==============================================================================
! Header and general information
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Header information...'
  END IF ! global%verbLevel

  READ(iFile,'(A)') sectionString
  IF ( TRIM(sectionString) /= '# ROCFLU species file' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,229,sectionString) 
  END IF ! TRIM  
  
! -----------------------------------------------------------------------------
! Precision and range
! -----------------------------------------------------------------------------
    
  READ(iFile,'(A)') sectionString
  IF ( TRIM(sectionString) /= '# Precision and range' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,238,sectionString) 
  END IF ! TRIM  
  
  precExpected  = PRECISION(1.0_RFREAL)
  rangeExpected = RANGE(1.0_RFREAL)
  
  READ(iFile,'(2(I8))') precActual,rangeActual
  IF ( precActual < precExpected .OR. rangeActual < rangeExpected ) THEN 
    CALL ErrorStop(global,ERR_PREC_RANGE,246)
  END IF ! precActual
  
! -----------------------------------------------------------------------------
! Physical time
! -----------------------------------------------------------------------------
  
  READ(iFile,'(A)') sectionString
  IF ( TRIM(sectionString) /= '# Physical time' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,255,iFileName)
  END IF ! TRIM    
   
  READ(iFile,'(E23.16)') currentTime 
 
  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    IF ( global%currentTime < 0.0_RFREAL ) THEN
      global%currentTime = currentTime
    ELSE
      WRITE(timeString1,'(1PE11.5)') global%currentTime
      WRITE(timeString2,'(1PE11.5)') currentTime          
      IF ( TRIM(timeString1) /= TRIM(timeString2) ) THEN
        CALL ErrorStop(global,ERR_TIME_SOLUTION,267,TRIM(iFileName))
      END IF ! global%currentTime 
    END IF ! global%currentTime
  END IF ! global%flowType  
  
! ==============================================================================
! Dimensions
! ==============================================================================
  
  pGrid => pRegion%grid  
  
  nVarsExpected  = pRegion%specInput%nSpecies
  nCellsExpected = pGrid%nCellsTot    
  
  READ(iFile,'(A)') sectionString
  IF ( TRIM(sectionString) /= '# Dimensions' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,283,sectionString) 
  END IF ! TRIM
    
  READ(iFile,'(2(I16))') nCellsTot,nVars
  IF ( nCellsTot /= nCellsExpected ) THEN 
    WRITE(errorString,'(A,1X,I6,1X,A,1X,I6)') 'Specified:',nCellsTot, & 
                                              'but expected:',nCellsExpected
    CALL ErrorStop(global,ERR_INVALID_NCELLS,290,errorString)
  END IF ! nCellsExpected     
  
  IF ( nVars /= nVarsExpected ) THEN 
    WRITE(errorString,'(A,1X,I6,1X,A,1X,I6)') 'Specified:',nVars, & 
                                              'but expected:',nVarsExpected  
    CALL ErrorStop(global,ERR_INVALID_NVARS,296)
  END IF ! nVarsExpected   
  
! ==============================================================================
! Rest of file
! ==============================================================================

  iVars       = 0
  loopCounter = 0

  DO ! set up infinite loop
    loopCounter = loopCounter + 1
  
    READ(iFile,'(A)') sectionString

    SELECT CASE ( TRIM(sectionString) ) 

! ------------------------------------------------------------------------------
!     Species concentration
! ------------------------------------------------------------------------------

      CASE ( '# Density' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species concentration...'
        END IF ! global%verbLevel    
      
        pCv => pRegion%spec%cv
      
        iVars = iVars + 1
        READ(iFile,'(5(E23.16))') (pCv(iVars,j),j=1,pGrid%nCellsTot)

! ------------------------------------------------------------------------------
!     End marker
! ------------------------------------------------------------------------------ 
      
      CASE ( '# End' ) 
        IF ( global%myProcid == MASTERPROC .AND. & 
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'End marker...'
        END IF ! global%verbLevel           
      
        EXIT
      
! ------------------------------------------------------------------------------
!     Invalid section string
! ------------------------------------------------------------------------------ 
      
      CASE DEFAULT
        IF ( global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,sectionString
        END IF ! verbosityLevel           
      
        CALL ErrorStop(global,ERR_INVALID_MARKER,349,sectionString)        
             
    END SELECT ! TRIM
  
! ------------------------------------------------------------------------------
!   Guard against infinite loop - might be unnecessary because of read errors?
! ------------------------------------------------------------------------------  
  
    IF ( loopCounter >= LIMIT_INFINITE_LOOP ) THEN 
      CALL ErrorStop(global,ERR_INFINITE_LOOP,358)
    END IF ! loopCounter
  
  END DO ! <empty>

! ==============================================================================
! Check and information about number of variables read
! ==============================================================================

  IF ( iVars /= nVars ) THEN 
    CALL ErrorStop(global,ERR_INVALID_NVARS,368)
  END IF ! iVar

! ==============================================================================
! Close file
! ==============================================================================

  CLOSE(iFile,IOSTAT=errorFlag)   
  global%error = errorFlag   
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_CLOSE,378,iFileName)
  END IF ! global%error
    
! ******************************************************************************
! End
! ******************************************************************************

   IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_NONE ) THEN   
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Reading ASCII species cv file done.'
  END IF ! global%verbLevel

  CALL DeregisterFunction(global)
 
END SUBROUTINE SPEC_RFLU_ReadCvASCII






! ******************************************************************************
!
! Purpose: Read flow file for species in binary ROCFLU format.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes:
!   1. Read physical time for both steady and unsteady flows so that could 
!      use steady solution as input for unsteady run and vice versa.
!   2. For GENX runs, read file from time zero if restarting. This is for 
!      convenience and will have to be changed once grid adaptation is used.
!
! ******************************************************************************

SUBROUTINE SPEC_RFLU_ReadCvBinary(pRegion)

  IMPLICIT NONE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
   
! ==============================================================================
! Local variables
! ==============================================================================

  LOGICAL :: fileExists
  CHARACTER(CHRLEN) :: errorString,iFileName,iFileNameOld,sectionString, &
                       timeString1,timeString2
  INTEGER :: errorFlag,i,iFile,iVars,j,loopCounter,nCellsTot,nCellsExpected, & 
             nVars,nVarsExpected,precActual,precExpected,rangeActual, & 
             rangeExpected
  REAL(RFREAL) :: currentTime
  REAL(RFREAL), DIMENSION(:,:), POINTER :: pCv
  TYPE(t_grid), POINTER :: pGrid
  TYPE(t_global), POINTER :: global
  
! ==============================================================================
! Arguments
! ==============================================================================

  TYPE(t_region), POINTER :: pRegion  
  
! ******************************************************************************
! Start, open file
! ******************************************************************************

  global => pRegion%global

  CALL RegisterFunction(global,'SPEC_RFLU_ReadCvBinary',"../rocspecies/SPEC_RFLU_ModReadWriteVars.F90")

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_NONE ) THEN 
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Reading binary species cv file...'
  END IF ! global%verbLevel

  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    CALL BuildFileNameUnsteady(global,FILEDEST_INDIR,'.spec.cv', & 
                               pRegion%iRegionGlobal,global%currentTime, &
                               iFileName)
    CALL BuildFileNameUnsteady(global,FILEDEST_INDIR,'.spc', & 
                               pRegion%iRegionGlobal,global%currentTime, &
                               iFileNameOld)                               
  ELSE
    CALL BuildFileNameSteady(global,FILEDEST_INDIR,'.spec.cv', & 
                             pRegion%iRegionGlobal,global%currentIter, &
                             iFileName)  
    CALL BuildFileNameSteady(global,FILEDEST_INDIR,'.spc', & 
                             pRegion%iRegionGlobal,global%currentIter, &
                             iFileNameOld)                               
  END IF ! global%flowType

  iFile = IF_SOLUT

  INQUIRE(FILE=iFileName,EXIST=fileExists)

  IF ( fileExists .EQV. .TRUE. ) THEN 
!    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="OLD",IOSTAT=errorFlag)
! BBR - begin
    IF( global%solutFormat .EQ. FORMAT_BINARY )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="OLD",IOSTAT=errorFlag)
    ELSEIF( global%solutFormat .EQ. FORMAT_BINARY_L )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="OLD", &
         ACCESS="SEQUENTIAL",CONVERT="LITTLE_ENDIAN",IOSTAT=errorFlag)
    ELSEIF( global%solutFormat .EQ. FORMAT_BINARY_B )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="OLD", &
         ACCESS="SEQUENTIAL",CONVERT="BIG_ENDIAN",IOSTAT=errorFlag)
    END IF
! BBR - end 
    global%error = errorFlag
    IF ( global%error /= ERR_NONE ) THEN
      CALL ErrorStop(global,ERR_FILE_OPEN,495,iFileName)
    END IF ! global%error
  ELSE 
!    OPEN(iFile,FILE=iFileNameOld,FORM="UNFORMATTED",STATUS="OLD", &
!         IOSTAT=errorFlag)
! BBR - begin
    IF( global%solutFormat .EQ. FORMAT_BINARY )THEN
    OPEN(iFile,FILE=iFileNameOld,FORM="UNFORMATTED",STATUS="OLD", &
         IOSTAT=errorFlag)
    ELSEIF( global%solutFormat .EQ. FORMAT_BINARY_L )THEN
    OPEN(iFile,FILE=iFileNameOld,FORM="UNFORMATTED",STATUS="OLD", &
         ACCESS="SEQUENTIAL",CONVERT="LITTLE_ENDIAN",IOSTAT=errorFlag)
    ELSEIF( global%solutFormat .EQ. FORMAT_BINARY_B )THEN
    OPEN(iFile,FILE=iFileNameOld,FORM="UNFORMATTED",STATUS="OLD", &
         ACCESS="SEQUENTIAL",CONVERT="BIG_ENDIAN",IOSTAT=errorFlag)
    END IF
! BBR - end 
    global%error = errorFlag
    IF ( global%error /= ERR_NONE ) THEN
      CALL ErrorStop(global,ERR_FILE_OPEN,514,iFileNameOld)
    END IF ! global%error    
  END IF ! fileExists

! ==============================================================================
! Set state vector state: Solution always stored in conservative form
! ==============================================================================

  pRegion%spec%cvState = CV_MIXT_STATE_CONS
  
! ==============================================================================
! Header and general information
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Header information...'
  END IF ! global%verbLevel

  READ(iFile) sectionString
  IF ( TRIM(sectionString) /= '# ROCFLU species file' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,535,sectionString) 
  END IF ! TRIM  
  
! -----------------------------------------------------------------------------
! Precision and range
! -----------------------------------------------------------------------------
    
  READ(iFile) sectionString
  IF ( TRIM(sectionString) /= '# Precision and range' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,544,sectionString) 
  END IF ! TRIM  
  
  precExpected  = PRECISION(1.0_RFREAL)
  rangeExpected = RANGE(1.0_RFREAL)
  
  READ(iFile) precActual,rangeActual
  IF ( precActual < precExpected .OR. rangeActual < rangeExpected ) THEN 
    CALL ErrorStop(global,ERR_PREC_RANGE,552)
  END IF ! precActual
  
! -----------------------------------------------------------------------------
! Physical time
! -----------------------------------------------------------------------------
  
  READ(iFile) sectionString
  IF ( TRIM(sectionString) /= '# Physical time' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,561,iFileName)
  END IF ! TRIM    
   
  READ(iFile) currentTime 
 
  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    IF ( global%currentTime < 0.0_RFREAL ) THEN
      global%currentTime = currentTime
    ELSE
      WRITE(timeString1,'(1PE11.5)') global%currentTime
      WRITE(timeString2,'(1PE11.5)') currentTime          
      IF ( TRIM(timeString1) /= TRIM(timeString2) ) THEN
        CALL ErrorStop(global,ERR_TIME_SOLUTION,573,TRIM(iFileName))
      END IF ! global%currentTime 
    END IF ! global%currentTime
  END IF ! global%flowType  
  
! ==============================================================================
! Dimensions
! ==============================================================================
  
  pGrid => pRegion%grid  
  
  nVarsExpected  = pRegion%specInput%nSpecies
  nCellsExpected = pGrid%nCellsTot    
  
  READ(iFile) sectionString
  IF ( TRIM(sectionString) /= '# Dimensions' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,589,sectionString) 
  END IF ! TRIM
    
  READ(iFile) nCellsTot,nVars
  IF ( nCellsTot /= nCellsExpected ) THEN 
    WRITE(errorString,'(A,1X,I6,1X,A,1X,I6)') 'Specified:',nCellsTot, & 
                                              'but expected:',nCellsExpected
    CALL ErrorStop(global,ERR_INVALID_NCELLS,596,errorString)
  END IF ! nCellsExpected     
  
  IF ( nVars /= nVarsExpected ) THEN 
    WRITE(errorString,'(A,1X,I6,1X,A,1X,I6)') 'Specified:',nVars, & 
                                              'but expected:',nVarsExpected  
    CALL ErrorStop(global,ERR_INVALID_NVARS,602)
  END IF ! nVarsExpected   
  
! ==============================================================================
! Rest of file
! ==============================================================================

  iVars       = 0
  loopCounter = 0

  DO ! set up infinite loop
    loopCounter = loopCounter + 1
  
    READ(iFile) sectionString

    SELECT CASE ( TRIM(sectionString) ) 

! ------------------------------------------------------------------------------
!     Species concentration
! ------------------------------------------------------------------------------

      CASE ( '# Density' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species concentration...'
        END IF ! global%verbLevel    
      
        pCv => pRegion%spec%cv
      
        iVars = iVars + 1
        READ(iFile) (pCv(iVars,j),j=1,pGrid%nCellsTot)

! ------------------------------------------------------------------------------
!     End marker
! ------------------------------------------------------------------------------ 
      
      CASE ( '# End' ) 
        IF ( global%myProcid == MASTERPROC .AND. & 
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'End marker...'
        END IF ! global%verbLevel           
      
        EXIT
      
! ------------------------------------------------------------------------------
!     Invalid section string
! ------------------------------------------------------------------------------ 
      
      CASE DEFAULT
        IF ( global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,sectionString
        END IF ! verbosityLevel           
      
        CALL ErrorStop(global,ERR_INVALID_MARKER,655,sectionString)        
             
    END SELECT ! TRIM
  
! ------------------------------------------------------------------------------
!   Guard against infinite loop - might be unnecessary because of read errors?
! ------------------------------------------------------------------------------  
  
    IF ( loopCounter >= LIMIT_INFINITE_LOOP ) THEN 
      CALL ErrorStop(global,ERR_INFINITE_LOOP,664)
    END IF ! loopCounter
  
  END DO ! <empty>

! ==============================================================================
! Check and information about number of variables read
! ==============================================================================

  IF ( iVars /= nVars ) THEN 
    CALL ErrorStop(global,ERR_INVALID_NVARS,674)
  END IF ! iVar

! ==============================================================================
! Close file
! ==============================================================================

  CLOSE(iFile,IOSTAT=errorFlag)   
  global%error = errorFlag   
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_CLOSE,684,iFileName)
  END IF ! global%error
    
! ******************************************************************************
! End
! ******************************************************************************

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_NONE ) THEN   
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Reading binary species cv file done.'
  END IF ! global%verbLevel

  CALL DeregisterFunction(global)
   
END SUBROUTINE SPEC_RFLU_ReadCvBinary









! ******************************************************************************
!
! Purpose: Read eev file for species in ASCII ROCFLU format.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes:
!   1. Read physical time for both steady and unsteady flows so that could 
!      use steady solution as input for unsteady run and vice versa.
!
! ******************************************************************************

SUBROUTINE SPEC_RFLU_ReadEEvASCII(pRegion)

  IMPLICIT NONE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
   
! ==============================================================================
! Local variables
! ==============================================================================

  CHARACTER(CHRLEN) :: errorString,iFileName,sectionString,timeString1, &
                       timeString2
  INTEGER :: errorFlag,iFile,iSpecEEvTemp,iSpecEEvXVel,iSpecEEvYVel, &
             iSpecEEvZVel,iVars,j,loopCounter,nCellsTot,nCellsExpected, & 
             nVars,nVarsExpected,precActual,precExpected,rangeActual, & 
             rangeExpected
  REAL(RFREAL) :: currentTime
  REAL(RFREAL), DIMENSION(:,:,:), POINTER :: pEEv
  TYPE(t_grid), POINTER :: pGrid
  TYPE(t_global), POINTER :: global
  
! ==============================================================================
! Arguments
! ==============================================================================

  TYPE(t_region), POINTER :: pRegion  
  
! ******************************************************************************
! Start, open file
! ******************************************************************************

  global => pRegion%global

  CALL RegisterFunction(global,'SPEC_RFLU_ReadEEvASCII',"../rocspecies/SPEC_RFLU_ModReadWriteVars.F90")

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_NONE ) THEN 
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Reading ASCII species eev file...'
  END IF ! global%verbLevel

  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    CALL BuildFileNameUnsteady(global,FILEDEST_INDIR,'.spec.eeva', & 
                               pRegion%iRegionGlobal,global%currentTime, &
                               iFileName)
  ELSE
    CALL BuildFileNameSteady(global,FILEDEST_INDIR,'.spec.eeva', & 
                             pRegion%iRegionGlobal,global%currentIter,iFileName)  
  END IF ! global%flowType

  iFile = IF_SOLUT
  OPEN(iFile,FILE=iFileName,FORM="FORMATTED",STATUS="OLD",IOSTAT=errorFlag)   
  global%error = errorFlag       
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_OPEN,780,iFileName)
  END IF ! global%error  

! ==============================================================================
! Header and general information
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Header information...'
  END IF ! global%verbLevel

  READ(iFile,'(A)') sectionString
  IF ( TRIM(sectionString) /= '# ROCFLU species eev file' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,794,sectionString) 
  END IF ! TRIM  
  
! -----------------------------------------------------------------------------
! Precision and range
! -----------------------------------------------------------------------------
    
  READ(iFile,'(A)') sectionString
  IF ( TRIM(sectionString) /= '# Precision and range' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,803,sectionString) 
  END IF ! TRIM  
  
  precExpected  = PRECISION(1.0_RFREAL)
  rangeExpected = RANGE(1.0_RFREAL)
  
  READ(iFile,'(2(I8))') precActual,rangeActual
  IF ( precActual < precExpected .OR. rangeActual < rangeExpected ) THEN 
    CALL ErrorStop(global,ERR_PREC_RANGE,811)
  END IF ! precActual
  
! -----------------------------------------------------------------------------
! Physical time
! -----------------------------------------------------------------------------
  
  READ(iFile,'(A)') sectionString
  IF ( TRIM(sectionString) /= '# Physical time' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,820,iFileName)
  END IF ! TRIM    
   
  READ(iFile,'(E23.16)') currentTime 
 
  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    IF ( global%currentTime < 0.0_RFREAL ) THEN
      global%currentTime = currentTime
    ELSE
      WRITE(timeString1,'(1PE11.5)') global%currentTime
      WRITE(timeString2,'(1PE11.5)') currentTime          
      IF ( TRIM(timeString1) /= TRIM(timeString2) ) THEN
        CALL ErrorStop(global,ERR_TIME_SOLUTION,832,TRIM(iFileName))
      END IF ! global%currentTime 
    END IF ! global%currentTime
  END IF ! global%flowType  
  
! ==============================================================================
! Dimensions
! ==============================================================================
  
  pGrid => pRegion%grid  
  
  nVarsExpected  = pRegion%specInput%nSpeciesEE*EEV_SPEC_NVAR
  nCellsExpected = pGrid%nCellsTot    
  
  READ(iFile,'(A)') sectionString
  IF ( TRIM(sectionString) /= '# Dimensions' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,848,sectionString) 
  END IF ! TRIM
    
  READ(iFile,'(2(I16))') nCellsTot,nVars
  IF ( nCellsTot /= nCellsExpected ) THEN 
    WRITE(errorString,'(A,1X,I6,1X,A,1X,I6)') 'Specified:',nCellsTot, & 
                                              'but expected:',nCellsExpected
    CALL ErrorStop(global,ERR_INVALID_NCELLS,855,errorString)
  END IF ! nCellsExpected     
  
  IF ( nVars /= nVarsExpected ) THEN 
    WRITE(errorString,'(A,1X,I6,1X,A,1X,I6)') 'Specified:',nVars, & 
                                              'but expected:',nVarsExpected  
    CALL ErrorStop(global,ERR_INVALID_NVARS,861)
  END IF ! nVarsExpected   
  
! ==============================================================================
! Rest of file
! ==============================================================================

  iSpecEEvXVel = 0
  iSpecEEvYVel = 0
  iSpecEEvZVel = 0    
  iSpecEEvTemp = 0
  loopCounter  = 0

  DO ! set up infinite loop
    loopCounter = loopCounter + 1
  
    READ(iFile,'(A)') sectionString

    SELECT CASE ( TRIM(sectionString) ) 

! ------------------------------------------------------------------------------
!     Species x-velocity
! ------------------------------------------------------------------------------

      CASE ( '# x-velocity' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species x-velocity...'
        END IF ! global%verbLevel    
      
        pEEv => pRegion%spec%eev
      
        iSpecEEvXVel = iSpecEEvXVel + 1
        READ(iFile,'(5(E23.16))') (pEEv(EEV_SPEC_XVEL,iSpecEEvXVel,j), &
                                  j=1,pGrid%nCellsTot)

! ------------------------------------------------------------------------------
!     Species y-velocity
! ------------------------------------------------------------------------------

      CASE ( '# y-velocity' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species y-velocity...'
        END IF ! global%verbLevel    
      
        pEEv => pRegion%spec%eev
      
        iSpecEEvYVel = iSpecEEvYVel + 1
        READ(iFile,'(5(E23.16))') (pEEv(EEV_SPEC_YVEL,iSpecEEvYVel,j), &
                                  j=1,pGrid%nCellsTot)

! ------------------------------------------------------------------------------
!     Species x-velocity
! ------------------------------------------------------------------------------

      CASE ( '# z-velocity' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species z-velocity...'
        END IF ! global%verbLevel    
      
        pEEv => pRegion%spec%eev
      
        iSpecEEvZVel = iSpecEEvZVel + 1
        READ(iFile,'(5(E23.16))') (pEEv(EEV_SPEC_ZVEL,iSpecEEvZVel,j), &
                                  j=1,pGrid%nCellsTot)
                                  
! ------------------------------------------------------------------------------
!     Species temperature
! ------------------------------------------------------------------------------

      CASE ( '# Temperature' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species temperature...'
        END IF ! global%verbLevel    
      
        pEEv => pRegion%spec%eev
      
        iSpecEEvTemp = iSpecEEvTemp + 1
        READ(iFile,'(5(E23.16))') (pEEv(EEV_SPEC_TEMP,iSpecEEvTemp,j), &
                                   j=1,pGrid%nCellsTot)

! ------------------------------------------------------------------------------
!     End marker
! ------------------------------------------------------------------------------ 
      
      CASE ( '# End' ) 
        IF ( global%myProcid == MASTERPROC .AND. & 
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'End marker...'
        END IF ! global%verbLevel           
      
        EXIT
      
! ------------------------------------------------------------------------------
!     Invalid section string
! ------------------------------------------------------------------------------ 
      
      CASE DEFAULT
        IF ( global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,sectionString
        END IF ! verbosityLevel           
      
        CALL ErrorStop(global,ERR_INVALID_MARKER,966,sectionString)        
                    
    END SELECT ! TRIM
  
! ------------------------------------------------------------------------------
!   Guard against infinite loop - might be unnecessary because of read errors?
! ------------------------------------------------------------------------------  
  
    IF ( loopCounter >= LIMIT_INFINITE_LOOP ) THEN 
      CALL ErrorStop(global,ERR_INFINITE_LOOP,975)
    END IF ! loopCounter
  END DO ! <empty>

! ==============================================================================
! Check and information about number of variables read
! ==============================================================================

  nVars = iSpecEEvXVel + iSpecEEvYVel + iSpecEEvZVel + iSpecEEvTemp

  IF ( nVars /= nVarsExpected ) THEN 
    CALL ErrorStop(global,ERR_INVALID_NVARS,986)
  END IF ! nVars

! ==============================================================================
! Close file
! ==============================================================================

  CLOSE(iFile,IOSTAT=errorFlag)   
  global%error = errorFlag   
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_CLOSE,996,iFileName)
  END IF ! global%error
    
! ******************************************************************************
! End
! ******************************************************************************
 
   IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_NONE ) THEN   
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Reading ASCII species eev file done.'
  END IF ! global%verbLevel

  CALL DeregisterFunction(global)
  
END SUBROUTINE SPEC_RFLU_ReadEEvASCII







! ******************************************************************************
!
! Purpose: Read eev file for species in binary ROCFLU format.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes:
!   1. Read physical time for both steady and unsteady flows so that could 
!      use steady solution as input for unsteady run and vice versa.
!
! ******************************************************************************

SUBROUTINE SPEC_RFLU_ReadEEvBinary(pRegion)

  IMPLICIT NONE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
   
! ==============================================================================
! Local variables
! ==============================================================================

  CHARACTER(CHRLEN) :: errorString,iFileName,sectionString,timeString1, & 
                       timeString2
  INTEGER :: errorFlag,iFile,iSpecEEvTemp,iSpecEEvXVel,iSpecEEvYVel, &
             iSpecEEvZVel,iVars,j,loopCounter,nCellsTot,nCellsExpected, & 
             nVars,nVarsExpected,precActual,precExpected,rangeActual, & 
             rangeExpected
  REAL(RFREAL) :: currentTime
  REAL(RFREAL), DIMENSION(:,:,:), POINTER :: pEEv
  TYPE(t_grid), POINTER :: pGrid
  TYPE(t_global), POINTER :: global
  
! ==============================================================================
! Arguments
! ==============================================================================

  TYPE(t_region), POINTER :: pRegion  
  
! ******************************************************************************
! Start, open file
! ******************************************************************************

  global => pRegion%global

  CALL RegisterFunction(global,'SPEC_RFLU_ReadEEvBinary',"../rocspecies/SPEC_RFLU_ModReadWriteVars.F90")

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_NONE ) THEN 
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Reading binary species eev file...'
  END IF ! global%verbLevel

  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    CALL BuildFileNameUnsteady(global,FILEDEST_INDIR,'.spec.eev', & 
                               pRegion%iRegionGlobal,global%currentTime, &
                               iFileName)
  ELSE
    CALL BuildFileNameSteady(global,FILEDEST_INDIR,'.spec.eev', & 
                             pRegion%iRegionGlobal,global%currentIter,iFileName)  
  END IF ! global%flowType

  iFile = IF_SOLUT
!  OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="OLD",IOSTAT=errorFlag)   
! BBR - begin
    IF( global%solutFormat .EQ. FORMAT_BINARY )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="OLD",IOSTAT=errorFlag)
    ELSEIF( global%solutFormat .EQ. FORMAT_BINARY_L )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="OLD", &
         ACCESS="SEQUENTIAL",CONVERT="LITTLE_ENDIAN",IOSTAT=errorFlag)
    ELSEIF( global%solutFormat .EQ. FORMAT_BINARY_B )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="OLD", &
         ACCESS="SEQUENTIAL",CONVERT="BIG_ENDIAN",IOSTAT=errorFlag)
    END IF
! BBR - end 
  global%error = errorFlag       
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_OPEN,1101,iFileName)
  END IF ! global%error  

! ==============================================================================
! Header and general information
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Header information...'
  END IF ! global%verbLevel

  READ(iFile) sectionString
  IF ( TRIM(sectionString) /= '# ROCFLU species eev file' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,1115,sectionString) 
  END IF ! TRIM  
  
! -----------------------------------------------------------------------------
! Precision and range
! -----------------------------------------------------------------------------
    
  READ(iFile) sectionString
  IF ( TRIM(sectionString) /= '# Precision and range' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,1124,sectionString) 
  END IF ! TRIM  
  
  precExpected  = PRECISION(1.0_RFREAL)
  rangeExpected = RANGE(1.0_RFREAL)
  
  READ(iFile) precActual,rangeActual
  IF ( precActual < precExpected .OR. rangeActual < rangeExpected ) THEN 
    CALL ErrorStop(global,ERR_PREC_RANGE,1132)
  END IF ! precActual
  
! -----------------------------------------------------------------------------
! Physical time
! -----------------------------------------------------------------------------
  
  READ(iFile) sectionString
  IF ( TRIM(sectionString) /= '# Physical time' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,1141,iFileName)
  END IF ! TRIM    
   
  READ(iFile) currentTime 
 
  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    IF ( global%currentTime < 0.0_RFREAL ) THEN
      global%currentTime = currentTime
    ELSE
      WRITE(timeString1,'(1PE11.5)') global%currentTime
      WRITE(timeString2,'(1PE11.5)') currentTime          
      IF ( TRIM(timeString1) /= TRIM(timeString2) ) THEN
        CALL ErrorStop(global,ERR_TIME_SOLUTION,1153,TRIM(iFileName))
      END IF ! global%currentTime 
    END IF ! global%currentTime
  END IF ! global%flowType  
  
! ==============================================================================
! Dimensions
! ==============================================================================
  
  pGrid => pRegion%grid  
  
  nVarsExpected  = pRegion%specInput%nSpeciesEE*EEV_SPEC_NVAR
  nCellsExpected = pGrid%nCellsTot    
  
  READ(iFile) sectionString
  IF ( TRIM(sectionString) /= '# Dimensions' ) THEN 
    CALL ErrorStop(global,ERR_INVALID_MARKER,1169,sectionString) 
  END IF ! TRIM
    
  READ(iFile) nCellsTot,nVars
  IF ( nCellsTot /= nCellsExpected ) THEN 
    WRITE(errorString,'(A,1X,I6,1X,A,1X,I6)') 'Specified:',nCellsTot, & 
                                              'but expected:',nCellsExpected
    CALL ErrorStop(global,ERR_INVALID_NCELLS,1176,errorString)
  END IF ! nCellsExpected     
  
  IF ( nVars /= nVarsExpected ) THEN 
    WRITE(errorString,'(A,1X,I6,1X,A,1X,I6)') 'Specified:',nVars, & 
                                              'but expected:',nVarsExpected  
    CALL ErrorStop(global,ERR_INVALID_NVARS,1182)
  END IF ! nVarsExpected   
  
! ==============================================================================
! Rest of file
! ==============================================================================

  iSpecEEvXVel = 0
  iSpecEEvYVel = 0
  iSpecEEvZVel = 0    
  iSpecEEvTemp = 0
  loopCounter  = 0

  DO ! set up infinite loop
    loopCounter = loopCounter + 1
  
    READ(iFile) sectionString

    SELECT CASE ( TRIM(sectionString) ) 

! ------------------------------------------------------------------------------
!     Species x-velocity
! ------------------------------------------------------------------------------

      CASE ( '# x-velocity' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species x-velocity...'
        END IF ! global%verbLevel    
      
        pEEv => pRegion%spec%eev
      
        iSpecEEvXVel = iSpecEEvXVel + 1
        READ(iFile) (pEEv(EEV_SPEC_XVEL,iSpecEEvXVel,j),j=1,pGrid%nCellsTot)

! ------------------------------------------------------------------------------
!     Species y-velocity
! ------------------------------------------------------------------------------

      CASE ( '# y-velocity' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species y-velocity...'
        END IF ! global%verbLevel    
      
        pEEv => pRegion%spec%eev
      
        iSpecEEvYVel = iSpecEEvYVel + 1
        READ(iFile) (pEEv(EEV_SPEC_YVEL,iSpecEEvYVel,j),j=1,pGrid%nCellsTot)

! ------------------------------------------------------------------------------
!     Species x-velocity
! ------------------------------------------------------------------------------

      CASE ( '# z-velocity' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species z-velocity...'
        END IF ! global%verbLevel    
      
        pEEv => pRegion%spec%eev
      
        iSpecEEvZVel = iSpecEEvZVel + 1
        READ(iFile) (pEEv(EEV_SPEC_ZVEL,iSpecEEvZVel,j),j=1,pGrid%nCellsTot)
                                  
! ------------------------------------------------------------------------------
!     Species temperature
! ------------------------------------------------------------------------------

      CASE ( '# Temperature' )
        IF ( global%myProcid == MASTERPROC .AND. &
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Species temperature...'
        END IF ! global%verbLevel    
      
        pEEv => pRegion%spec%eev
      
        iSpecEEvTemp = iSpecEEvTemp + 1
        READ(iFile) (pEEv(EEV_SPEC_TEMP,iSpecEEvTemp,j),j=1,pGrid%nCellsTot)

! ------------------------------------------------------------------------------
!     End marker
! ------------------------------------------------------------------------------ 
      
      CASE ( '# End' ) 
        IF ( global%myProcid == MASTERPROC .AND. & 
             global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'End marker...'
        END IF ! global%verbLevel           
      
        EXIT
      
! ------------------------------------------------------------------------------
!     Invalid section string
! ------------------------------------------------------------------------------ 
      
      CASE DEFAULT
        IF ( global%verbLevel > VERBOSE_LOW ) THEN  
          WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,sectionString
        END IF ! verbosityLevel           
      
        CALL ErrorStop(global,ERR_INVALID_MARKER,1283,sectionString)        
                    
    END SELECT ! TRIM
  
! ------------------------------------------------------------------------------
!   Guard against infinite loop - might be unnecessary because of read errors?
! ------------------------------------------------------------------------------  
  
    IF ( loopCounter >= LIMIT_INFINITE_LOOP ) THEN 
      CALL ErrorStop(global,ERR_INFINITE_LOOP,1292)
    END IF ! loopCounter
  END DO ! <empty>

! ==============================================================================
! Check and information about number of variables read
! ==============================================================================

  nVars = iSpecEEvXVel + iSpecEEvYVel + iSpecEEvZVel + iSpecEEvTemp

  IF ( nVars /= nVarsExpected ) THEN 
    CALL ErrorStop(global,ERR_INVALID_NVARS,1303)
  END IF ! nVars

! ==============================================================================
! Close file
! ==============================================================================

  CLOSE(iFile,IOSTAT=errorFlag)   
  global%error = errorFlag   
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_CLOSE,1313,iFileName)
  END IF ! global%error
    
! ******************************************************************************
! End
! ******************************************************************************
 
  IF ( global%myProcid == MASTERPROC .AND. & 
       global%verbLevel > VERBOSE_NONE ) THEN   
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Reading binary species eev file done.'
  END IF ! global%verbLevel

  CALL DeregisterFunction(global)
   
END SUBROUTINE SPEC_RFLU_ReadEEvBinary








! ******************************************************************************
!
! Purpose: Write flow file for species in ASCII ROCFLU format.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: 
!   1. Write physical time for both steady and unsteady flows so that could 
!      use steady solution as input for unsteady run and vice versa.
!
! ******************************************************************************

SUBROUTINE SPEC_RFLU_WriteCvASCII(pRegion)

  IMPLICIT NONE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
   
! ==============================================================================
! Local variables
! ==============================================================================

  CHARACTER(CHRLEN) :: iFileName,sectionString
  INTEGER :: errorFlag,iFile,iVar,j,nVars
  REAL(RFREAL), DIMENSION(:,:), POINTER :: pCv
  TYPE(t_grid), POINTER :: pGrid
  TYPE(t_global), POINTER :: global
  
! ==============================================================================
! Arguments
! ==============================================================================

  TYPE(t_region), POINTER :: pRegion  
  
! ******************************************************************************
! Start, open file
! ******************************************************************************

  global => pRegion%global

  CALL RegisterFunction(global,'SPEC_RFLU_WriteCvASCII',"../rocspecies/SPEC_RFLU_ModReadWriteVars.F90")

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_NONE ) THEN 
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Writing ASCII species cv file...'
  END IF ! global%verbLevel

  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    CALL BuildFileNameUnsteady(global,FILEDEST_OUTDIR,'.spec.cva', & 
                               pRegion%iRegionGlobal,global%currentTime, & 
                               iFileName)  
  ELSE
    CALL BuildFileNameSteady(global,FILEDEST_OUTDIR,'.spec.cva', & 
                             pRegion%iRegionGlobal,global%currentIter, &
                             iFileName)
  END IF ! global%flowType

  iFile = IF_SOLUT
  OPEN(iFile,FILE=iFileName,FORM="FORMATTED",STATUS="UNKNOWN", &
       IOSTAT=errorFlag)
  global%error = errorFlag
  IF ( global%error /= ERR_NONE ) THEN
    CALL ErrorStop(global,ERR_FILE_OPEN,1405,iFileName)
  END IF ! global%error

! ==============================================================================
! Header and general information
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Header information...'
  END IF ! global%verbLevel

  sectionString = '# ROCFLU species file'
  WRITE(iFile,'(A)') sectionString
  
  sectionString = '# Precision and range'
  WRITE(iFile,'(A)') sectionString
  WRITE(iFile,'(2(I8))') PRECISION(1.0_RFREAL),RANGE(1.0_RFREAL)
  
  sectionString = '# Physical time'
  WRITE(iFile,'(A)') sectionString
  WRITE(iFile,'(E23.16)') global%currentTime 

! ==============================================================================
! Dimensions
! ==============================================================================
  
  nVars = pRegion%specInput%nSpecies
  
  pGrid => pRegion%grid  
  
  sectionString = '# Dimensions'
  WRITE(iFile,'(A)') sectionString
  WRITE(iFile,'(2(I16))') pGrid%nCellsTot,nVars 
  
! ==============================================================================
! Species concentration
! ==============================================================================

  pCv => pRegion%spec%cv

  DO iVar = 1,nVars
    sectionString = '# Density'
    WRITE(iFile,'(A)') sectionString
    WRITE(iFile,'(5(E23.16))') (pCv(iVar,j),j=1,pGrid%nCellsTot)
  END DO ! iVar
 
! ==============================================================================
! End marker
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'End marker...'
  END IF ! global%verbLevel

  sectionString = '# End'
  WRITE(iFile,'(A)') sectionString  

! ==============================================================================
! Close file
! ==============================================================================

  CLOSE(iFile,IOSTAT=errorFlag)
  global%error = errorFlag      
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_CLOSE,1471,iFileName)
  END IF ! global%error
    
! ******************************************************************************
! End
! ******************************************************************************
 
  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_NONE ) THEN   
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Writing ASCII species cv file done.'
  END IF ! global%verbLevel

  CALL DeregisterFunction(global)
   
END SUBROUTINE SPEC_RFLU_WriteCvASCII







! ******************************************************************************
!
! Purpose: Write flow file for species in binary ROCFLU format.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: 
!   1. Write physical time for both steady and unsteady flows so that could 
!      use steady solution as input for unsteady run and vice versa.
!
! ******************************************************************************

SUBROUTINE SPEC_RFLU_WriteCvBinary(pRegion)

  IMPLICIT NONE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
   
! ==============================================================================
! Local variables
! ==============================================================================

  CHARACTER(CHRLEN) :: iFileName,sectionString
  INTEGER :: errorFlag,iFile,iVar,j,nVars
  REAL(RFREAL), DIMENSION(:,:), POINTER :: pCv
  TYPE(t_grid), POINTER :: pGrid
  TYPE(t_global), POINTER :: global
  
! ==============================================================================
! Arguments
! ==============================================================================

  TYPE(t_region), POINTER :: pRegion  
  
! ******************************************************************************
! Start, open file
! ******************************************************************************

  global => pRegion%global

  CALL RegisterFunction(global,'SPEC_RFLU_WriteCvBinary',"../rocspecies/SPEC_RFLU_ModReadWriteVars.F90")

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_NONE ) THEN 
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Writing binary species cv  file...'
  END IF ! global%verbLevel

  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    CALL BuildFileNameUnsteady(global,FILEDEST_OUTDIR,'.spec.cv', & 
                               pRegion%iRegionGlobal,global%currentTime, & 
                               iFileName)                             
  ELSE
    CALL BuildFileNameSteady(global,FILEDEST_OUTDIR,'.spec.cv', & 
                             pRegion%iRegionGlobal,global%currentIter, &
                             iFileName)                                
  END IF ! global%flowType

  iFile = IF_SOLUT
!  OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="UNKNOWN", &
!       IOSTAT=errorFlag)
! BBR - begin
    IF( global%solutFormat .EQ. FORMAT_BINARY )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="UNKNOWN", &
         IOSTAT=errorFlag)
    ELSEIF( global%solutFormat .EQ. FORMAT_BINARY_L )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="UNKNOWN", &
         ACCESS="SEQUENTIAL",CONVERT="LITTLE_ENDIAN",IOSTAT=errorFlag)
    ELSEIF( global%solutFormat .EQ. FORMAT_BINARY_B )THEN
    OPEN(iFile,FILE=iFileName,FORM="UNFORMATTED",STATUS="UNKNOWN", &
         ACCESS="SEQUENTIAL",CONVERT="BIG_ENDIAN",IOSTAT=errorFlag)
    END IF
! BBR - end 
  global%error = errorFlag
  IF ( global%error /= ERR_NONE ) THEN
    CALL ErrorStop(global,ERR_FILE_OPEN,1574,iFileName)
  END IF ! global%error

! ==============================================================================
! Header and general information
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Header information...'
  END IF ! global%verbLevel

  sectionString = '# ROCFLU species file'
  WRITE(iFile) sectionString
  
  sectionString = '# Precision and range'
  WRITE(iFile) sectionString
  WRITE(iFile) PRECISION(1.0_RFREAL),RANGE(1.0_RFREAL)
  
  sectionString = '# Physical time'
  WRITE(iFile) sectionString
  WRITE(iFile) global%currentTime 

! ==============================================================================
! Dimensions
! ==============================================================================
  
  nVars = pRegion%specInput%nSpecies
  
  pGrid => pRegion%grid  
  
  sectionString = '# Dimensions'
  WRITE(iFile) sectionString
  WRITE(iFile) pGrid%nCellsTot,nVars 
  
! ==============================================================================
! Species concentration
! ==============================================================================

  pCv => pRegion%spec%cv

  DO iVar = 1,nVars
    sectionString = '# Density'
    WRITE(iFile) sectionString
    WRITE(iFile) (pCv(iVar,j),j=1,pGrid%nCellsTot)
  END DO ! iVar
 
! ==============================================================================
! End marker
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'End marker...'
  END IF ! global%verbLevel

  sectionString = '# End'
  WRITE(iFile) sectionString  

! ==============================================================================
! Close file
! ==============================================================================

  CLOSE(iFile,IOSTAT=errorFlag)
  global%error = errorFlag      
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_CLOSE,1640,iFileName)
  END IF ! global%error
   
! ******************************************************************************
! End
! ******************************************************************************

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_NONE ) THEN   
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Writing binary species cv file done.'
  END IF ! global%verbLevel

  CALL DeregisterFunction(global)
 
END SUBROUTINE SPEC_RFLU_WriteCvBinary






! ******************************************************************************
!
! Purpose: Write eev file for species in ASCII ROCFLU format.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: 
!   1. Write physical time for both steady and unsteady flows so that could 
!      use steady solution as input for unsteady run and vice versa.
!
! ******************************************************************************

SUBROUTINE SPEC_RFLU_WriteEEvASCII(pRegion)

  IMPLICIT NONE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
   
! ==============================================================================
! Local variables
! ==============================================================================

  CHARACTER(CHRLEN) :: iFileName,sectionString
  INTEGER :: errorFlag,iFile,iSpecEE,j,nVars
  REAL(RFREAL), DIMENSION(:,:,:), POINTER :: pEEv
  TYPE(t_grid), POINTER :: pGrid
  TYPE(t_global), POINTER :: global
  
! ==============================================================================
! Arguments
! ==============================================================================

  TYPE(t_region), POINTER :: pRegion  
  
! ******************************************************************************
! Start, open file
! ******************************************************************************

  global => pRegion%global

  CALL RegisterFunction(global,'SPEC_RFLU_WriteEEvASCII',"../rocspecies/SPEC_RFLU_ModReadWriteVars.F90")

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_NONE ) THEN 
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Writing ASCII species eev file...'
  END IF ! global%verbLevel

  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    CALL BuildFileNameUnsteady(global,FILEDEST_OUTDIR,'.spec.eeva', & 
                               pRegion%iRegionGlobal,global%currentTime, & 
                               iFileName)
  ELSE
    CALL BuildFileNameSteady(global,FILEDEST_OUTDIR,'.spec.eeva', & 
                             pRegion%iRegionGlobal,global%currentIter,iFileName)  
  ENDIF ! global%flowType

  iFile = IF_SOLUT
  OPEN(iFile,FILE=iFileName,FORM="FORMATTED",STATUS="UNKNOWN",IOSTAT=errorFlag)
  global%error = errorFlag          
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_OPEN,1728,iFileName)
  END IF ! global%error  

! ==============================================================================
! Header and general information
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Header information...'
  END IF ! global%verbLevel

  sectionString = '# ROCFLU species eev file'
  WRITE(iFile,'(A)') sectionString
  
  sectionString = '# Precision and range'
  WRITE(iFile,'(A)') sectionString
  WRITE(iFile,'(2(I8))') PRECISION(1.0_RFREAL),RANGE(1.0_RFREAL)
  
  sectionString = '# Physical time'
  WRITE(iFile,'(A)') sectionString
  WRITE(iFile,'(E23.16)') global%currentTime 

! ==============================================================================
! Dimensions
! ==============================================================================
  
  nVars = pRegion%specInput%nSpeciesEE*EEV_SPEC_NVAR
  
  pGrid => pRegion%grid  
  
  sectionString = '# Dimensions'
  WRITE(iFile,'(A)') sectionString
  WRITE(iFile,'(2(I16))') pGrid%nCellsTot,nVars 
  
! ==============================================================================
! Variables
! ==============================================================================

  pEEv => pRegion%spec%eev

  DO iSpecEE = 1,pRegion%specInput%nSpeciesEE
    sectionString = '# x-velocity'
    WRITE(iFile,'(A)') sectionString
    WRITE(iFile,'(5(E23.16))') (pEEv(EEV_SPEC_XVEL,iSpecEE,j), &
                               j=1,pGrid%nCellsTot)
                            
    sectionString = '# y-velocity'
    WRITE(iFile,'(A)') sectionString
    WRITE(iFile,'(5(E23.16))') (pEEv(EEV_SPEC_YVEL,iSpecEE,j), &
                               j=1,pGrid%nCellsTot)
                               
    sectionString = '# z-velocity'
    WRITE(iFile,'(A)') sectionString
    WRITE(iFile,'(5(E23.16))') (pEEv(EEV_SPEC_ZVEL,iSpecEE,j), &
                               j=1,pGrid%nCellsTot)  
                               
    sectionString = '# Temperature'
    WRITE(iFile,'(A)') sectionString
    WRITE(iFile,'(5(E23.16))') (pEEv(EEV_SPEC_TEMP,iSpecEE,j), &
                               j=1,pGrid%nCellsTot)                                                                                            
  END DO ! iSpecEE
 
! ==============================================================================
! End marker
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'End marker...'
  END IF ! global%verbLevel

  sectionString = '# End'
  WRITE(iFile,'(A)') sectionString  

! ==============================================================================
! Close file
! ==============================================================================

  CLOSE(iFile,IOSTAT=errorFlag)
  global%error = errorFlag      
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_CLOSE,1810,iFileName)
  END IF ! global%error
       
! ******************************************************************************
! End
! ******************************************************************************
 
   IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_NONE ) THEN   
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Writing ASCII species eev file done.'
  END IF ! global%verbLevel

  CALL DeregisterFunction(global)

END SUBROUTINE SPEC_RFLU_WriteEEvASCII





! ******************************************************************************
!
! Purpose: Write eev file for species in binary ROCFLU format.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: 
!   1. Write physical time for both steady and unsteady flows so that could 
!      use steady solution as input for unsteady run and vice versa.
!
! ******************************************************************************

SUBROUTINE SPEC_RFLU_WriteEEvBinary(pRegion)

  IMPLICIT NONE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
   
! ==============================================================================
! Local variables
! ==============================================================================

  CHARACTER(CHRLEN) :: iFileName,sectionString
  INTEGER :: errorFlag,iFile,iSpecEE,j,nVars
  REAL(RFREAL), DIMENSION(:,:,:), POINTER :: pEEv
  TYPE(t_grid), POINTER :: pGrid
  TYPE(t_global), POINTER :: global
  
! ==============================================================================
! Arguments
! ==============================================================================

  TYPE(t_region), POINTER :: pRegion  
  
! ******************************************************************************
! Start, open file
! ******************************************************************************

  global => pRegion%global

  CALL RegisterFunction(global,'SPEC_RFLU_WriteEEvBinary',"../rocspecies/SPEC_RFLU_ModReadWriteVars.F90")

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_NONE ) THEN 
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Writing binary species eev file...'
  END IF ! global%verbLevel

  IF ( global%flowType == FLOW_UNSTEADY ) THEN
    CALL BuildFileNameUnsteady(global,FILEDEST_OUTDIR,'.spec.eev', & 
                               pRegion%iRegionGlobal,global%currentTime, & 
                               iFileName)
  ELSE
    CALL BuildFileNameSteady(global,FILEDEST_OUTDIR,'.spec.eev', & 
                             pRegion%iRegionGlobal,global%currentIter,iFileName)  
  ENDIF ! global%flowType

  iFile = IF_SOLUT
  OPEN(iFile,FILE=iFileName,FORM="FORMATTED",STATUS="UNKNOWN",IOSTAT=errorFlag)
  global%error = errorFlag          
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_OPEN,1897,iFileName)
  END IF ! global%error  

! ==============================================================================
! Header and general information
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'Header information...'
  END IF ! global%verbLevel

  sectionString = '# ROCFLU species eev file'
  WRITE(iFile) sectionString
  
  sectionString = '# Precision and range'
  WRITE(iFile) sectionString
  WRITE(iFile) PRECISION(1.0_RFREAL),RANGE(1.0_RFREAL)
  
  sectionString = '# Physical time'
  WRITE(iFile) sectionString
  WRITE(iFile) global%currentTime 

! ==============================================================================
! Dimensions
! ==============================================================================
  
  nVars = pRegion%specInput%nSpeciesEE*EEV_SPEC_NVAR
  
  pGrid => pRegion%grid  
  
  sectionString = '# Dimensions'
  WRITE(iFile) sectionString
  WRITE(iFile) pGrid%nCellsTot,nVars 
  
! ==============================================================================
! Variables
! ==============================================================================

  pEEv => pRegion%spec%eev

  DO iSpecEE = 1,pRegion%specInput%nSpeciesEE
    sectionString = '# x-velocity'
    WRITE(iFile) sectionString
    WRITE(iFile) (pEEv(EEV_SPEC_XVEL,iSpecEE,j),j=1,pGrid%nCellsTot)
                            
    sectionString = '# y-velocity'
    WRITE(iFile) sectionString
    WRITE(iFile) (pEEv(EEV_SPEC_YVEL,iSpecEE,j),j=1,pGrid%nCellsTot)
                               
    sectionString = '# z-velocity'
    WRITE(iFile) sectionString
    WRITE(iFile) (pEEv(EEV_SPEC_ZVEL,iSpecEE,j),j=1,pGrid%nCellsTot)  
                               
    sectionString = '# Temperature'
    WRITE(iFile) sectionString
    WRITE(iFile) (pEEv(EEV_SPEC_TEMP,iSpecEE,j),j=1,pGrid%nCellsTot)                                                                                            
  END DO ! iSpecEE
 
! ==============================================================================
! End marker
! ==============================================================================

  IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_LOW ) THEN  
    WRITE(STDOUT,'(A,3X,A)') SOLVER_NAME,'End marker...'
  END IF ! global%verbLevel

  sectionString = '# End'
  WRITE(iFile) sectionString  

! ==============================================================================
! Close file
! ==============================================================================

  CLOSE(iFile,IOSTAT=errorFlag)
  global%error = errorFlag      
  IF ( global%error /= ERR_NONE ) THEN 
    CALL ErrorStop(global,ERR_FILE_CLOSE,1975,iFileName)
  END IF ! global%error
       
! ******************************************************************************
! End
! ******************************************************************************
 
   IF ( global%myProcid == MASTERPROC .AND. &
       global%verbLevel > VERBOSE_NONE ) THEN   
    WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Writing ASCII species eev file done.'
  END IF ! global%verbLevel

  CALL DeregisterFunction(global)

END SUBROUTINE SPEC_RFLU_WriteEEvBinary




! ******************************************************************************
! End
! ******************************************************************************

END MODULE SPEC_RFLU_ModReadWriteVars


! ******************************************************************************
!
! RCS Revision history:
!
! $Log: SPEC_RFLU_ModReadWriteVars.F90,v $
! Revision 1.2  2015/07/23 23:11:19  brollin
! 1) The pressure coefficient of the  collision model has been changed back to its original form
! 2) New options in the format of the grid and solutions have been added. Now the user can choose the endianness, and convert from one to the over in rfluconv.
! 3) The solutions are now stored in folders named by timestamp or iteration number.
! 4) The address enty in the hashtable has been changed to an integer(8) for cases when the grid becomes very large.
! 5) RFLU_WritePM can now compute PM2 on the fly for the Macroscale problem
!
! Revision 1.1.1.1  2015/01/23 22:57:50  tbanerjee
! merged rocflu micro and macro
!
! Revision 1.1.1.1  2014/07/15 14:31:38  brollin
! New Stable version
!
! Revision 1.3  2008/12/06 08:43:53  mtcampbe
! Updated license.
!
! Revision 1.2  2008/11/19 22:17:05  mtcampbe
! Added Illinois Open Source License/Copyright
!
! Revision 1.1  2007/04/09 18:51:23  haselbac
! Initial revision after split from RocfloMP
!
! Revision 1.1  2007/04/09 18:01:50  haselbac
! Initial revision after split from RocfloMP
!
! Revision 1.2  2007/04/05 12:44:52  haselbac
! Removed superfluous close parentheses - found by ifort compiler
!
! Revision 1.1  2005/11/27 01:47:26  haselbac
! Initial revision
!
! ******************************************************************************

