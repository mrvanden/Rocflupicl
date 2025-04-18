










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
! Purpose: Suite of routines to build boundary lists.
!
! Description: None.
!
! Notes:
!   1. The creation and destruction routines are needed despite the existence
!      of RFLU_CreateGrid.F90 and RFLU_DestroyGrid.F90 because rfluprep needs
!      to construct the boundary vertex lists from the exterior grid formats. 
!
! ******************************************************************************
!
! $Id: RFLU_ModBoundLists.F90,v 1.1.1.1 2015/01/23 22:57:50 tbanerjee Exp $
!
! Copyright: (c) 2002-2005 by the University of Illinois
!
! ******************************************************************************

MODULE RFLU_ModBoundLists

  USE ModGlobal, ONLY: t_global
  USE ModDataTypes
  USE ModParameters
  USE ModError
  USE ModBndPatch, ONLY: t_patch
  USE ModDataStruct, ONLY: t_region
  USE ModGrid, ONLY: t_grid
  USE ModMPI

  USE RFLU_ModRenumberList

  IMPLICIT NONE

  PRIVATE
  PUBLIC :: RFLU_BuildBCellMList, & 
            RFLU_BuildBFaceLocLists, &
            RFLU_BuildBFaceSortLists, &
            RFLU_BuildBVertexLists, &
            RFLU_BuildBVertexMList, &
            RFLU_CreateBCellMList, &  
            RFLU_CreateBFaceLocLists, & 
            RFLU_CreateBFaceSortLists, & 
            RFLU_CreateBVertexLists, &
            RFLU_CreateBVertexMList, &
            RFLU_DenumberBFaceLists, &
            RFLU_DestroyBCellMList, & 
            RFLU_DestroyBFaceLocLists, &
            RFLU_DestroyBFaceSortLists, & 
            RFLU_DestroyBVertexLists, & 
            RFLU_DestroyBVertexMList, &
            RFLU_NullifyBCellMList, &              
            RFLU_NullifyBFaceLocLists, &
            RFLU_NullifyBFaceSortLists, & 
            RFLU_NullifyBVertexLists, & 
            RFLU_NullifyBVertexMList, &
            RFLU_RenumberBFaceLists 
  
  SAVE
  
! ******************************************************************************
! Declarations and definitions
! ******************************************************************************  
      
  CHARACTER(CHRLEN) :: & 
    RCSIdentString = '$RCSfile: RFLU_ModBoundLists.F90,v $ $Revision: 1.1.1.1 $' 
              
! *****************************************************************************
! Routines
! *****************************************************************************

  CONTAINS
  






! ******************************************************************************
!
! Purpose: Build master boundary-cell list.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: 
!   1. Include virtual faces because need to capture faces of virtual cells 
!      from symmetry and periodic patches when using the master boundary-cell
!      list to build list of boundary faces for partitioned regions.
!   2. Master boundary-cell list for cases with virtual cells from symmetry 
!      and periodic patches includes cells from symmetry and periodic patches
!      although face list lists those faces as AV faces.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_BuildBCellMList(pRegion)

    USE ModSortSearch, ONLY: QuickSortInteger, & 
                             SimplifySortedIntegers  

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,ifl,ifl2,iPatch,nBCells
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_BuildBCellMList',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Building master boundary-cell list...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Build merged boundary-cell list which may contain duplicates 
! ******************************************************************************

    nBCells = 0

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      DO ifl = 1,pPatch%nBFacesTot
        ifl2 = nBCells + ifl

        pGrid%bcm(ifl2) = pPatch%bf2c(ifl)
      END DO ! ifl        

      nBCells = nBCells + pPatch%nBFacesTot
    END DO ! iPatch

! ******************************************************************************
!   Eliminate duplicates
! ******************************************************************************

    IF ( nBCells > 0 ) THEN 
      CALL QuickSortInteger(pGrid%bcm(1:nBCells),nBCells)    
      CALL SimplifySortedIntegers(global,pGrid%bcm(1:nBCells),nBCells, & 
                                  pGrid%nBCells)
    END IF ! nBCells

! ******************************************************************************
!   Write info
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_LOW ) THEN  
      WRITE(STDOUT,'(A,3X,A,1X,I9)') SOLVER_NAME,'Number of boundary cells:', &
                                     pGrid%nBCells
    END IF ! global%verbLevel    

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Building master boundary-cell list done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_BuildBCellMList









! ******************************************************************************
!
! Purpose: Build local boundary face lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_BuildBFaceLocLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,ifl,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_BuildBFaceLocLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Building local boundary-face lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Build local boundary connectivity lists for each patch
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      IF ( pPatch%nBTrisTot > 0 ) THEN     
        DO ifl = 1,pPatch%nBTrisTot
          pPatch%bTri2vLoc(1,ifl) = pPatch%bTri2v(1,ifl)
          pPatch%bTri2vLoc(2,ifl) = pPatch%bTri2v(2,ifl)
          pPatch%bTri2vLoc(3,ifl) = pPatch%bTri2v(3,ifl)                        
        END DO ! ifl

        CALL RFLU_RenumberList(global,3,pPatch%nBTrisTot, & 
                               pPatch%bTri2vLoc(1:3,1:pPatch%nBTrisTot), & 
                               pPatch%nBVertTot,pPatch%bv(1:pPatch%nBVertTot))
      END IF ! pPatch%nBTrisTot

      IF ( pPatch%nBQuadsTot > 0 ) THEN 
        DO ifl = 1,pPatch%nBQuadsTot
          pPatch%bQuad2vLoc(1,ifl) = pPatch%bQuad2v(1,ifl)
          pPatch%bQuad2vLoc(2,ifl) = pPatch%bQuad2v(2,ifl)
          pPatch%bQuad2vLoc(3,ifl) = pPatch%bQuad2v(3,ifl)
          pPatch%bQuad2vLoc(4,ifl) = pPatch%bQuad2v(4,ifl)                        
        END DO ! ifl
        
        CALL RFLU_RenumberList(global,4,pPatch%nBQuadsTot, & 
                               pPatch%bQuad2vLoc(1:4,1:pPatch%nBQuadsTot), & 
                               pPatch%nBVertTot,pPatch%bv(1:pPatch%nBVertTot))        
      END IF ! pPatch%nBQuadsTot
    END DO ! iPatch

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Building local boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_BuildBFaceLocLists







! ******************************************************************************
!
! Purpose: Build sorted boundary face lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_BuildBFaceSortLists(pRegion)

    USE ModSortSearch, ONLY: QuickSortInteger

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,ifl,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_BuildBFaceSortLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Building sorted boundary-face lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Build sorted boundary cell list for each patch
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      DO ifl = 1,pPatch%nBFacesTot
        pPatch%bf2cSorted(ifl) = pPatch%bf2c(ifl)
      END DO ! ifl

      CALL QuickSortInteger(pPatch%bf2cSorted,pPatch%nBFacesTot)
    END DO ! iPatch

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Building sorted boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_BuildBFaceSortLists







  
! ******************************************************************************
!
! Purpose: Build boundary vertex lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_BuildBVertexLists(pRegion)

    USE ModSortSearch

    USE RFLU_ModHashTable                                 

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: actualCntr,errorFlag,ic,ifc,iloc,iPatch,iq,it,ivg,ivl,key, & 
               virtualCntr
    INTEGER, DIMENSION(:), ALLOCATABLE :: bvActual,bvVirtual
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_BuildBVertexLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN    
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Building boundary-vertex lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Loop over patches
! ******************************************************************************

    pGrid => pRegion%grid  

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      CALL RFLU_CreateHashTable(global,pPatch%nBVertEst)  

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_NONE ) THEN
        WRITE(STDOUT,'(A,3X,A,1X,I3)') SOLVER_NAME,'Boundary:',iPatch
        WRITE(STDOUT,'(A,5X,A,2X,I16)') SOLVER_NAME,'Estimated number of '// & 
                                       'vertices:',pPatch%nBVertEst  

        IF ( global%myProcid == MASTERPROC .AND. & 
             global%verbLevel > VERBOSE_NONE ) THEN
          WRITE(STDOUT,'(A,5X,A,13X,I9)') SOLVER_NAME,'Hash table size: ', & 
                                          hashTableSize
        END IF ! global%myProcid
      END IF ! global%myProcid

! ==============================================================================
!     Initialize counters. NOTE important because incremented and for GENX runs
!     get size of boundary vertices from HDF files, so they are NOT zero when
!     this routine is called.
! ==============================================================================

      pPatch%nBVert    = 0 
      pPatch%nBVertTot = 0

! ==============================================================================
!     Triangles
! ==============================================================================

      DO it = 1,pPatch%nBTrisTot
        ivg = pPatch%bTri2v(1,it)
        CALL RFLU_HashBuildKey1(ivg,key)          
        CALL RFLU_HashVertex(global,key,ivg,pPatch%nBVertTot,pPatch%bvTemp)        

        ivg = pPatch%bTri2v(2,it)
        CALL RFLU_HashBuildKey1(ivg,key)          
        CALL RFLU_HashVertex(global,key,ivg,pPatch%nBVertTot,pPatch%bvTemp)        

        ivg = pPatch%bTri2v(3,it)
        CALL RFLU_HashBuildKey1(ivg,key)          
        CALL RFLU_HashVertex(global,key,ivg,pPatch%nBVertTot,pPatch%bvTemp)        
      END DO ! it

! ==============================================================================
!     Quadrilaterals 
! ==============================================================================

      DO iq = 1,pPatch%nBQuadsTot
        ivg = pPatch%bQuad2v(1,iq)
        CALL RFLU_HashBuildKey1(ivg,key)          
        CALL RFLU_HashVertex(global,key,ivg,pPatch%nBVertTot,pPatch%bvTemp)        

        ivg = pPatch%bQuad2v(2,iq)
        CALL RFLU_HashBuildKey1(ivg,key)          
        CALL RFLU_HashVertex(global,key,ivg,pPatch%nBVertTot,pPatch%bvTemp)        

        ivg = pPatch%bQuad2v(3,iq)
        CALL RFLU_HashBuildKey1(ivg,key)          
        CALL RFLU_HashVertex(global,key,ivg,pPatch%nBVertTot,pPatch%bvTemp)        

        ivg = pPatch%bQuad2v(4,iq)
        CALL RFLU_HashBuildKey1(ivg,key)          
        CALL RFLU_HashVertex(global,key,ivg,pPatch%nBVertTot,pPatch%bvTemp)        
      END DO ! iq  

! ==============================================================================
!     Print some info on hash table and actual number of vertices
! ==============================================================================

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN
        WRITE(STDOUT,'(A,5X,A,18X,I9)') SOLVER_NAME,'Collisions: ', & 
                                        hashTableCollisions
      END IF ! global%myProcid

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_NONE ) THEN
        WRITE(STDOUT,'(A,5X,A,6X,I16)') SOLVER_NAME,'Total number of '// & 
                                       'vertices:',pPatch%nBVertTot
      END IF ! global%myProcid

! ==============================================================================
!     Destroy hash table
! ==============================================================================

      CALL RFLU_DestroyHashTable(global)

! ******************************************************************************
!     Count number of actual and virtual boundary vertices
! ******************************************************************************

      pPatch%nBVert = 0

      DO ivl = 1,pPatch%nBVertTot
        ivg = pPatch%bvTemp(ivl)

        IF ( ivg <= pGrid%nVert ) THEN                      
          pPatch%nBVert = pPatch%nBVert + 1
        END IF ! ivg
      END DO ! ivg

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_NONE ) THEN
        WRITE(STDOUT,'(A,7X,A,13X,I16)') SOLVER_NAME,'Actual vertices:', &
                                        pPatch%nBVert
        WRITE(STDOUT,'(A,7X,A,12X,I16)') SOLVER_NAME,'Virtual vertices:', &
                                        pPatch%nBVertTot - pPatch%nBVert
      END IF ! global%myProcid        

! ******************************************************************************
!     Sort and store boundary vertex list - NOTE actual and virtual vertices
!     are stored separately
! ******************************************************************************

      ALLOCATE(pPatch%bv(pPatch%nBVertTot),STAT=errorFlag)
      global%error = errorFlag    
      IF ( global%error /= ERR_NONE ) THEN 
        CALL ErrorStop(global,ERR_ALLOCATE,647,'pPatch%bv')
      END IF ! global%error

      IF ( pPatch%nBVert > 0 ) THEN 
        ALLOCATE(bvActual(pPatch%nBVert),STAT=errorFlag)
        global%error = errorFlag    
        IF ( global%error /= ERR_NONE ) THEN 
          CALL ErrorStop(global,ERR_ALLOCATE,654,'bvActual')
        END IF ! global%error 
      END IF ! pPatch%nBVert

      IF ( pPatch%nBVertTot /= pPatch%nBVert ) THEN 
        ALLOCATE(bvVirtual(pPatch%nBVertTot-pPatch%nBVert),STAT=errorFlag)
        global%error = errorFlag    
        IF ( global%error /= ERR_NONE ) THEN 
          CALL ErrorStop(global,ERR_ALLOCATE,662,'bvVirtual')
        END IF ! global%error
      END IF ! pPatch%nBVertTot

! ******************************************************************************
!     Sort actual and virtual vertices into separate (unsorted lists)
! ******************************************************************************

      actualCntr  = 0
      virtualCntr = 0

      DO ivl = 1,pPatch%nBVertTot
        ivg = pPatch%bvTemp(ivl)

        IF ( ivg <= pGrid%nVert ) THEN 
          actualCntr = actualCntr + 1            
          bvActual(actualCntr) = pPatch%bvTemp(ivl)
        ELSE IF ( ivg <= pGrid%nVertTot ) THEN 
          virtualCntr = virtualCntr + 1
          bvVirtual(virtualCntr) = pPatch%bvTemp(ivl)
        ELSE
          CALL ErrorStop(global,ERR_REACHED_DEFAULT,683)
        END IF ! ivg
      END DO ! ivl

      IF ( (actualCntr /= pPatch%nBVert) .OR. & 
           (virtualCntr /= (pPatch%nBVertTot - pPatch%nBVert)) ) THEN 
        CALL ErrorStop(global,ERR_NBVERT_EXTREMA,689)
      END IF ! actualCntr

! ******************************************************************************
!     Sort unsorted lists and merge into single list
! ******************************************************************************

! ==============================================================================
!     Actual vertices 
! ==============================================================================

      IF ( pPatch%nBVert > 0 ) THEN 
        CALL QuickSortInteger(bvActual,pPatch%nBVert)    
      END IF ! nBVert

      pPatch%bv(1:pPatch%nBVert) = bvActual(1:pPatch%nBVert)

! ==============================================================================
!     Virtual vertices 
! ==============================================================================

      IF ( pPatch%nBVertTot /= pPatch%nBVert ) THEN 
        CALL QuickSortInteger(bvVirtual,pPatch%nBVertTot-pPatch%nBVert)    

        pPatch%bv((pPatch%nBVert+1):pPatch%nBVertTot) = & 
          bvVirtual(1:(pPatch%nBVertTot-pPatch%nBVert))   

        DEALLOCATE(bvVirtual,STAT=errorFlag)
        global%error = errorFlag    
        IF ( global%error /= ERR_NONE ) THEN 
          CALL ErrorStop(global,ERR_DEALLOCATE,719,'bvVirtual')
        END IF ! global%error                  
      END IF ! pPatch%nBVertTot

      IF ( pPatch%nBVert > 0 ) THEN 
        DEALLOCATE(bvActual,STAT=errorFlag)
        global%error = errorFlag    
        IF ( global%error /= ERR_NONE ) THEN 
          CALL ErrorStop(global,ERR_DEALLOCATE,727,'bvActual')
        END IF ! global%error 
      END IF ! pPatch%nBVert         

      DEALLOCATE(pPatch%bvTemp,STAT=errorFlag)
      global%error = errorFlag    
      IF ( global%error /= ERR_NONE ) THEN 
        CALL ErrorStop(global,ERR_DEALLOCATE,734,'pPatch%bvTemp')
      END IF ! global%error  
    END DO ! iPatch


! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Building boundary-vertex lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_BuildBVertexLists







! ******************************************************************************
!
! Purpose: Build boundary-vertex master list.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************

  SUBROUTINE RFLU_BuildBVertexMList(pRegion)

    USE ModSortSearch, ONLY: MergeSortedIntegers      

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: bvmSize,errorFlag,iPatch,iv,nBVertTemp,workArraySize
    INTEGER, DIMENSION(:), ALLOCATABLE :: bvmTemp,workArray
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_BuildBVertexMList',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Building boundary-vertex master list...'   
    END IF ! global%verbLevel

    pGrid => pRegion%grid  

! ******************************************************************************
!   Initialize variables and list
! ******************************************************************************

    pGrid%nBVert = 0

    DO iv = 1,pGrid%nBVertEst
      pGrid%bvm(iv) = 0 ! Initial value not important
    END DO ! iv

! ******************************************************************************
!   Loop over patches
! ******************************************************************************

    DO iPatch=1,pGrid%nPatches 
      pPatch => pRegion%patches(iPatch)

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN
        WRITE(STDOUT,'(A,3X,A,1X,I3)') SOLVER_NAME,'Patch:',iPatch   
      END IF ! global%verbLevel      

! ==============================================================================
!     Build list
! ==============================================================================

      IF ( iPatch > 1 ) THEN 
        workArraySize = nBVertTemp + pPatch%nBVertTot

        ALLOCATE(workArray(workArraySize),STAT=errorFlag)
        global%error = errorFlag
        IF ( global%error /= ERR_NONE ) THEN
          CALL ErrorStop(global,ERR_ALLOCATE,870,'workArray')
        END IF ! global%error

        DO iv = 1,workArraySize
          workArray(iv) = 0
        END DO ! iv

        bvmSize = nBVertTemp ! Next call does not work otherwise... 

        CALL MergeSortedIntegers(global,bvmSize,pPatch%nBVertTot, & 
                                 pGrid%bvm(1:nBVertTemp), &
                                 pPatch%bv(1:pPatch%nBVertTot), &
                                 workArraySize,nBVertTemp,workArray)

        DO iv = 1,nBVertTemp
          pGrid%bvm(iv) = workArray(iv)
        END DO ! iv

        DEALLOCATE(workArray,STAT=errorFlag)
        global%error = errorFlag
        IF ( global%error /= ERR_NONE ) THEN
          CALL ErrorStop(global,ERR_DEALLOCATE,891,'workArray')
        END IF ! global%error          
      ELSE
        DO iv = 1,pPatch%nBVertTot
          pGrid%bvm(iv) = pPatch%bv(iv)
        END DO ! iv

        bvmSize    = 0
        nBVertTemp = pPatch%nBVertTot
      END IF ! iPatch 

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN
        WRITE(STDOUT,'(A,5X,A,1X,I6,1X,A)') SOLVER_NAME,'Contributed', & 
                                            nBVertTemp-bvmSize, & 
                                            'new vertices.' 
      END IF ! global%verbLevel        
    END DO ! iPatch    

! ******************************************************************************
!   Copy over into actual list
! ******************************************************************************    

    pGrid%nBVert = nBVertTemp    

    ALLOCATE(bvmTemp(pGrid%nBVert),STAT=errorFlag)
    global%error = errorFlag    
    IF ( global%error /= ERR_NONE ) THEN 
      CALL ErrorStop(global,ERR_ALLOCATE,919,'bvmTemp')
    END IF ! global%error

    DO iv = 1,pGrid%nBVert
      bvmTemp(iv) = pGrid%bvm(iv)
    END DO ! iv

    DEALLOCATE(pGrid%bvm,STAT=errorFlag)
    global%error = errorFlag    
    IF ( global%error /= ERR_NONE ) THEN 
      CALL ErrorStop(global,ERR_DEALLOCATE,929,'pGrid%bvm')
    END IF ! global%error      

    ALLOCATE(pGrid%bvm(pGrid%nBVert),STAT=errorFlag)
    global%error = errorFlag    
    IF ( global%error /= ERR_NONE ) THEN 
      CALL ErrorStop(global,ERR_ALLOCATE,935,'pGrid%bvm')
    END IF ! global%error

    DO iv = 1,pGrid%nBVert
      pGrid%bvm(iv) = bvmTemp(iv)
    END DO ! iv

    DEALLOCATE(bvmTemp,STAT=errorFlag)
    global%error = errorFlag    
    IF ( global%error /= ERR_NONE ) THEN 
      CALL ErrorStop(global,ERR_DEALLOCATE,945,'bvmTemp')
    END IF ! global%error      

! ==============================================================================
!   Write some info
! ==============================================================================    

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,3X,A,I9)') SOLVER_NAME, & 
                                  'Number of vertices:',pGrid%nBVert
    END IF ! global%verbLevel

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Building boundary-vertex master list done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)    

  END SUBROUTINE RFLU_BuildBVertexMList







! ******************************************************************************
!
! Purpose: Create master boundary cell list.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: 
!   1. The dimension used in the allocation statement is only an estimate. This
!      estimate is guaranteed to be larger than the actual number of cells
!      which are adjacent to boundary faces.
!   2. Only makes sense to build master boundary-cell list for serial cases, so
!      use nBFaces, not nBFacesTot for allocation.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_CreateBCellMList(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,iPatch,nBCells
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_CreateBCellMList',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Creating master boundary-cell list...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBCellMList(pRegion)

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Allocate memory
! ******************************************************************************

    pGrid%nBCells = 0 

    nBCells = 0

    DO iPatch = 1,pGrid%nPatches
      pPatch => pRegion%patches(iPatch)
      
      nBCells = nBCells + pPatch%nBFacesTot
    END DO ! iPatch

    ALLOCATE(pGrid%bcm(nBCells),STAT=errorFlag)
    global%error = errorFlag
    IF ( global%error /= ERR_NONE ) THEN 
      CALL ErrorStop(global,ERR_ALLOCATE,1064,'pGrid%bcm')
    END IF ! global%error
 
! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Creating master boundary-cell list done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_CreateBCellMList







! ******************************************************************************
!
! Purpose: Create local boundary face lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_CreateBFaceLocLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_CreateBFaceLocLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Creating local boundary-face lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBFaceLocLists(pRegion)

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Create local boundary connectivity lists for each patch
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      IF ( pPatch%nBTrisTot > 0 ) THEN 
        ALLOCATE(pPatch%bTri2vLoc(3,pPatch%nBTrisTot),STAT=errorFlag)
        global%error = errorFlag
        IF ( global%error /= ERR_NONE ) THEN 
          CALL ErrorStop(global,ERR_ALLOCATE,1162,'pPatch%bTri2vLoc')
        END IF ! global%error
      END IF ! pPatch%nBTris

      IF ( pPatch%nBQuadsTot > 0 ) THEN 
        ALLOCATE(pPatch%bQuad2vLoc(4,pPatch%nBQuadsTot),STAT=errorFlag)
        global%error = errorFlag
        IF ( global%error /= ERR_NONE ) THEN 
          CALL ErrorStop(global,ERR_ALLOCATE,1170,'pPatch%bQuad2vLoc')
        END IF ! global%error
      END IF ! pPatch%nBQuads
    END DO ! iPatch

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Creating local boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_CreateBFaceLocLists







! ******************************************************************************
!
! Purpose: Create sorted boundary face lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_CreateBFaceSortLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_CreateBFaceSortLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Creating sorted boundary-face lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBFaceSortLists(pRegion)

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Create local boundary connectivity lists for each patch
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      ALLOCATE(pPatch%bf2cSorted(pPatch%nBFacesTot),STAT=errorFlag)
      global%error = errorFlag
      IF ( global%error /= ERR_NONE ) THEN 
        CALL ErrorStop(global,ERR_ALLOCATE,1269,'pPatch%bf2cSorted')
      END IF ! global%error
    END DO ! iPatch

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Creating sorted boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_CreateBFaceSortLists






  
! ******************************************************************************
!
! Purpose: Create boundary vertex lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_CreateBVertexLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,ibv,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_CreateBVertexLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME,'Creating boundary vertex lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBVertexLists(pRegion)

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Create list of boundary vertices for each patch
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

! ==============================================================================
!     Estimate number of boundary vertices
! ==============================================================================      

      SELECT CASE ( pRegion%mixtInput%dimens ) 
        CASE ( 1 ) 
          pPatch%nBVertEst = 2*pPatch%nBQuadsTot + 2
        CASE ( 2 ) 
          IF ( pPatch%bcType /= BC_VIRTUAL ) THEN 
            pPatch%nBVertEst = 2*pPatch%nBQuadsTot + 2
          ELSE 
            pPatch%nBVertEst = 4*(pPatch%nBTrisTot/2 + pPatch%nBQuadsTot)
          END IF ! pPatch%bcType
        CASE ( 3 )               
          pPatch%nBVertEst = 2*(pPatch%nBTrisTot/2 + pPatch%nBQuadsTot)
        
          IF ( pPatch%nBVertEst < 100 ) THEN ! Kludge
            pPatch%nBVertEst = 100 + 4*pPatch%nBVertEst 
          ELSE IF ( pPatch%nBVertEst < 1000 ) THEN 
            pPatch%nBVertEst = 2*pPatch%nBVertEst
          END IF ! pPatch%nBVertEst         
        CASE DEFAULT
          CALL ErrorStop(global,ERR_REACHED_DEFAULT,1385)
      END SELECT ! pRegion%mixtInput%dimens          

      pPatch%nBVertEst = NINT(pPatch%nBVertEst*global%nBVertEstCorrFactor)

! ==============================================================================
!     Allocate memory for temporary boundary vertex array
! ==============================================================================

      ALLOCATE(pPatch%bvTemp(pPatch%nBVertEst),STAT=errorFlag)
      global%error = errorFlag   
      IF ( global%error /= ERR_NONE ) THEN 
        CALL ErrorStop(global,ERR_ALLOCATE,1397,'pPatch%bvTemp')
      END IF ! global%error      

      DO ibv = 1,pPatch%nBVertEst
        pPatch%bvTemp(ibv) = 0  
      END DO ! ibv
    END DO ! iPatch

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME,'Creating boundary vertex', & 
                                    'lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_CreateBVertexLists








! ******************************************************************************
!
! Purpose: Create boundary vertex master list.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************

  SUBROUTINE RFLU_CreateBVertexMList(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_CreateBVertexMList',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Creating boundary vertex master list...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBVertexMList(pRegion)

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Allocate memory
! ******************************************************************************

    pGrid%nBVertEst = 0

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      pGrid%nBVertEst = pGrid%nBVertEst + pPatch%nBVertTot
    END DO ! iPatch

    ALLOCATE(pGrid%bvm(pGrid%nBVertEst),STAT=errorFlag)
    global%error = errorFlag    
    IF ( global%error /= ERR_NONE ) THEN 
      CALL ErrorStop(global,ERR_ALLOCATE,1505,'pGrid%bvm')
    END IF ! global%error

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, &
            'Creating master boundary vertex list done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_CreateBVertexMList







! ******************************************************************************
!
! Purpose: Denumber combined boundary face list.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_DenumberBFaceLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,ifl,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_DenumberBFaceLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Denumbering boundary-face lists...'   
    END IF ! global%verbLevel

! ******************************************************************************
!   Loop over patches
! ******************************************************************************

    pGrid => pRegion%grid  

    DO iPatch = 1,pGrid%nPatches 
      pPatch => pRegion%patches(iPatch)

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN
        WRITE(STDOUT,'(A,3X,A,1X,I3)') SOLVER_NAME,'Patch:',iPatch   
      END IF ! global%verbLevel    

! ==============================================================================
!     Check renumbering flag
! ============================================================================== 

      IF ( pPatch%renumFlag .EQV. .FALSE. ) THEN
        global%warnCounter = global%warnCounter + 1

        IF ( global%myProcid == MASTERPROC .AND. & 
             global%verbLevel > VERBOSE_LOW ) THEN 
          WRITE(STDOUT,'(A,5X,A,1X,A)') SOLVER_NAME, & 
             '*** WARNING *** Patch already denumbered. Skipping denumbering.'
          CYCLE
        END IF ! global
      END IF ! pPatch%renumFlag

! ==============================================================================
!     Actual faces
! ==============================================================================

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN
        WRITE(STDOUT,'(A,5X,A)') SOLVER_NAME,'Actual faces...'   
      END IF ! global%verbLevel 

      CALL RFLU_DenumberList(global,4,pPatch%nBFaces, & 
                             pPatch%bf2v(1:4,1:pPatch%nBFaces), & 
                             pPatch%nBVert,pPatch%bv(1:pPatch%nBVert))

! ==============================================================================
!     Virtual faces
! ==============================================================================

      IF ( pPatch%nBFacesTot > pPatch%nBFaces .AND. & 
           global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN
        WRITE(STDOUT,'(A,5X,A)') SOLVER_NAME,'Virtual faces...'   
      END IF ! global%verbLevel           

      IF ( pPatch%nBFacesTot > pPatch%nBFaces ) THEN 
        CALL RFLU_DenumberList(global,4,pPatch%nBFacesTot-pPatch%nBFaces, & 
             pPatch%bf2v(1:4,pPatch%nBFaces+1:pPatch%nBFacesTot), & 
             pPatch%nBVertTot,pPatch%bv(1:pPatch%nBVertTot))
      END IF ! pPatch%nBFaces

! ==============================================================================
!     Set renumbering flag
! ==============================================================================

      pPatch%renumFlag = .FALSE.        
    END DO ! iPatch


! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Denumbering boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_DenumberBFaceLists







! ******************************************************************************
!
! Purpose: Destroy master boundary-cell lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_DestroyBCellMList(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_DestroyBCellMList',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Destroying master boundary-cell list...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Create local boundary connectivity lists for each patch
! ******************************************************************************

    DEALLOCATE(pGrid%bcm,STAT=errorFlag)
    global%error = errorFlag
    IF ( global%error /= ERR_NONE ) THEN 
      CALL ErrorStop(global,ERR_DEALLOCATE,1759,'pGrid%bcm')
    END IF ! global%error

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBCellMList(pRegion)

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Destroying master boundary-cell list done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_DestroyBCellMList








! ******************************************************************************
!
! Purpose: Destroy local boundary face lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_DestroyBFaceLocLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_DestroyBFaceLocLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Destroying local boundary-face lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Create local boundary connectivity lists for each patch
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      IF ( pPatch%nBTrisTot > 0 ) THEN 
        DEALLOCATE(pPatch%bTri2vLoc,STAT=errorFlag)
        global%error = errorFlag
        IF ( global%error /= ERR_NONE ) THEN 
          CALL ErrorStop(global,ERR_DEALLOCATE,1858,'pPatch%bTri2vLoc')
        END IF ! global%error
      END IF ! pPatch%nBTris

      IF ( pPatch%nBQuadsTot > 0 ) THEN 
        DEALLOCATE(pPatch%bQuad2vLoc,STAT=errorFlag)
        global%error = errorFlag
        IF ( global%error /= ERR_NONE ) THEN 
          CALL ErrorStop(global,ERR_DEALLOCATE,1866,'pPatch%bQuad2vLoc')
        END IF ! global%error
      END IF ! pPatch%nBQuads
    END DO ! iPatch

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBFaceLocLists(pRegion)

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Destroying local boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_DestroyBFaceLocLists








! ******************************************************************************
!
! Purpose: Destroy sorted boundary face lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_DestroyBFaceSortLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_DestroyBFaceSortLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Destroying sorted boundary-face lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Create local boundary connectivity lists for each patch
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      DEALLOCATE(pPatch%bf2cSorted,STAT=errorFlag)
      global%error = errorFlag
      IF ( global%error /= ERR_NONE ) THEN 
        CALL ErrorStop(global,ERR_DEALLOCATE,1966,'pPatch%bf2cSorted')
      END IF ! global%error
    END DO ! iPatch

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBFaceSortLists(pRegion)

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
            'Destroying sorted boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_DestroyBFaceSortLists







! ******************************************************************************
!
! Purpose:  Destroy boundary lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
  
  SUBROUTINE RFLU_DestroyBVertexLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion  

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,iPatch
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch
    TYPE(t_global), POINTER :: global

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global  

    CALL RegisterFunction(global,'RFLU_DestroyBoundLists',"../modflu/RFLU_ModBoundLists.F90")                

    IF ( global%myProcid == MASTERPROC .AND. &
         global%verbLevel > VERBOSE_NONE ) THEN                 
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Destroying boundary-vertex lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid     

! ******************************************************************************
!   Loop over patches
! ******************************************************************************

    DO iPatch = 1,pGrid%nPatches
      pPatch => pRegion%patches(iPatch)   

      DEALLOCATE(pPatch%bv,STAT=errorFlag)
      global%error = errorFlag   
      IF ( global%error /= ERR_NONE ) THEN 
        CALL ErrorStop(global,ERR_DEALLOCATE,2064,'pPatch%bv')
      END IF ! global%error 
    END DO ! iPatch      

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBVertexLists(pRegion)

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. &
         global%verbLevel > VERBOSE_NONE ) THEN 
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Destroying boundary-vertex lists done.'
    END IF ! global%verbLevel  

    CALL DeregisterFunction(global)  

  END SUBROUTINE RFLU_DestroyBVertexLists
 



 

! ******************************************************************************
!
! Purpose: Destroy boundary vertex master list.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
  
  SUBROUTINE RFLU_DestroyBVertexMList(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion  

! ==============================================================================
!   Locals
! ============================================================================== 

    INTEGER :: errorFlag,iPatch
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch
    TYPE(t_global), POINTER :: global

! ******************************************************************************
!   Start
! ******************************************************************************      

    global => pRegion%global  

    CALL RegisterFunction(global,'RFLU_DestroyBVertexMList',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. &
         global%verbLevel > VERBOSE_NONE ) THEN                 
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Destroying boundary-vertex master list...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid     

! ******************************************************************************
!   Destroy list
! ******************************************************************************

    DEALLOCATE(pGrid%bvm,STAT=errorFlag)
    global%error = errorFlag   
    IF ( global%error /= ERR_NONE ) THEN 
      CALL ErrorStop(global,ERR_DEALLOCATE,2158,'pGrid%bvm')
    END IF ! global%error                        

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    CALL RFLU_NullifyBVertexMList(pRegion)

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. &
         global%verbLevel > VERBOSE_NONE ) THEN 
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Destroying boundary-vertex master list done.'
    END IF ! global%verbLevel  

    CALL DeregisterFunction(global)  

  END SUBROUTINE RFLU_DestroyBVertexMList







! ******************************************************************************
!
! Purpose: Nullify master boundary-cell lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_NullifyBCellMList(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_NullifyBCellMList',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Nullifying master boundary-cell list...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    NULLIFY(pGrid%bcm)

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
            'Nullifying master boundary-cell list done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_NullifyBCellMList 




    
      
      
! ******************************************************************************
!
! Purpose: Nullify local boundary-face lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_NullifyBFaceLocLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_NullifyBFaceLocLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Nullifying local boundary-face lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      NULLIFY(pPatch%bTri2vLoc)
      NULLIFY(pPatch%bQuad2vLoc)
    END DO ! iPatch

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Nullifying local boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_NullifyBFaceLocLists 









! ******************************************************************************
!
! Purpose: Nullify sorted boundary-face lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_NullifyBFaceSortLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_NullifyBFaceSortLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Nullifying sorted boundary-face lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      NULLIFY(pPatch%bf2cSorted)
    END DO ! iPatch

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
            'Nullifying sorted boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_NullifyBFaceSortLists










! ******************************************************************************
!
! Purpose: Nullify boundary vertex lists.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_NullifyBVertexLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_NullifyBVertexLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Nullifying boundary vertex lists...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    DO iPatch = 1,pRegion%grid%nPatches
      pPatch => pRegion%patches(iPatch)

      NULLIFY(pPatch%bv)
      NULLIFY(pPatch%bvTemp)
    END DO ! iPatch

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A,1X,A)') SOLVER_NAME, & 
                                    'Nullifying boundary vertex lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_NullifyBVertexLists 






! ******************************************************************************
!
! Purpose: Nullify boundary vertex master list.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
    SUBROUTINE RFLU_NullifyBVertexMList(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_NullifyBVertexMList',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN       
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Nullifying boundary vertex master list...'
    END IF ! global%verbLevel

! ******************************************************************************
!   Set grid pointer
! ******************************************************************************

    pGrid => pRegion%grid  

! ******************************************************************************
!   Nullify memory
! ******************************************************************************

    NULLIFY(pGrid%bvm)

! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, & 
                               'Nullifying boundary vertex master list done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_NullifyBVertexMList       
      
      
      
      
      
      
      
! ******************************************************************************
!
! Purpose: Renumber combined boundary face list.
!
! Description: None.
!
! Input:
!   pRegion     Pointer to region
!
! Output: None.
!
! Notes: None.
!
! ******************************************************************************
    
  SUBROUTINE RFLU_RenumberBFaceLists(pRegion)

    IMPLICIT NONE

! ******************************************************************************
!   Declarations and definitions
! ******************************************************************************

! ==============================================================================
!   Arguments
! ==============================================================================

    TYPE(t_region), POINTER :: pRegion

! ==============================================================================
!   Locals
! ==============================================================================

    INTEGER :: errorFlag,ifl,iPatch
    TYPE(t_global), POINTER :: global
    TYPE(t_grid), POINTER :: pGrid
    TYPE(t_patch), POINTER :: pPatch

! ******************************************************************************
!   Start
! ******************************************************************************

    global => pRegion%global

    CALL RegisterFunction(global,'RFLU_RenumberBFaceLists',"../modflu/RFLU_ModBoundLists.F90")

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Renumbering boundary-face lists...'   
    END IF ! global%verbLevel

! ******************************************************************************
!   Loop over patches
! ******************************************************************************

    pGrid => pRegion%grid  

    DO iPatch = 1,pGrid%nPatches 
      pPatch => pRegion%patches(iPatch)

      IF ( global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN
        WRITE(STDOUT,'(A,3X,A,1X,I3)') SOLVER_NAME,'Patch:',iPatch   
      END IF ! global%verbLevel    

! ==============================================================================
!     Check renumbering flag
! ==============================================================================

      IF ( pPatch%renumFlag .EQV. .TRUE. ) THEN
        global%warnCounter = global%warnCounter + 1

        IF ( global%myProcid == MASTERPROC .AND. & 
             global%verbLevel > VERBOSE_LOW ) THEN 
          WRITE(STDOUT,'(A,5X,A)') SOLVER_NAME, &
             '*** WARNING *** Patch already renumbered. Skipping renumbering.'
          CYCLE
        END IF ! global         
      END IF ! pPatch%renumFlag 

! ==============================================================================
!     Actual faces
! ==============================================================================

      IF ( pPatch%nBFaces > 0 .AND. &
           global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN                      
        WRITE(STDOUT,'(A,5X,A)') SOLVER_NAME,'Actual faces...'   
      END IF ! global%verbLevel 

      IF ( pPatch%nBFaces > 0 ) THEN 
        CALL RFLU_RenumberList(global,4,pPatch%nBFaces, & 
                               pPatch%bf2v(1:4,1:pPatch%nBFaces), & 
                               pPatch%nBVert,pPatch%bv(1:pPatch%nBVert)) 
      END IF ! pPatch%nBFaces

! ==============================================================================
!     Virtual faces
! ==============================================================================

      IF ( pPatch%nBFacesTot > pPatch%nBFaces .AND. &
           global%myProcid == MASTERPROC .AND. & 
           global%verbLevel > VERBOSE_LOW ) THEN
        WRITE(STDOUT,'(A,5X,A)') SOLVER_NAME,'Virtual faces...'   
      END IF ! global%verbLevel 

      IF ( pPatch%nBFacesTot > pPatch%nBFaces ) THEN 
        CALL RFLU_RenumberList(global,4,pPatch%nBFacesTot-pPatch%nBFaces, & 
             pPatch%bf2v(1:4,pPatch%nBFaces+1:pPatch%nBFacesTot), & 
             pPatch%nBVertTot,pPatch%bv(1:pPatch%nBVertTot))         
      END IF ! pPatch%nBFaces

! ==============================================================================
!     Set renumbering flag
! ============================================================================== 

      pPatch%renumFlag = .TRUE.
    END DO ! iPatch


! ******************************************************************************
!   End
! ******************************************************************************

    IF ( global%myProcid == MASTERPROC .AND. & 
         global%verbLevel > VERBOSE_NONE ) THEN  
      WRITE(STDOUT,'(A,1X,A)') SOLVER_NAME, &
                               'Renumbering boundary-face lists done.'
    END IF ! global%verbLevel

    CALL DeregisterFunction(global)

  END SUBROUTINE RFLU_RenumberBFaceLists

  


! ******************************************************************************
! End
! ******************************************************************************
  
END MODULE RFLU_ModBoundLists


! ******************************************************************************
!
! RCS Revision history:
!
! $Log: RFLU_ModBoundLists.F90,v $
! Revision 1.1.1.1  2015/01/23 22:57:50  tbanerjee
! merged rocflu micro and macro
!
! Revision 1.1.1.1  2014/07/15 14:31:36  brollin
! New Stable version
!
! Revision 1.5  2008/12/06 08:43:39  mtcampbe
! Updated license.
!
! Revision 1.4  2008/11/19 22:16:54  mtcampbe
! Added Illinois Open Source License/Copyright
!
! Revision 1.3  2007/11/28 23:05:18  mparmar
! Added increment of boundary vertex estimate by nBVertEstCorrFactor
!
! Revision 1.2  2007/05/30 17:13:26  haselbac
! Adapted to changes in SimplifySortedIntegers
!
! Revision 1.1  2007/04/09 18:49:23  haselbac
! Initial revision after split from RocfloMP
!
! Revision 1.1  2007/04/09 18:00:39  haselbac
! Initial revision after split from RocfloMP
!
! Revision 1.31  2007/02/27 13:02:27  haselbac
! Enabled 1d computations
!
! Revision 1.30  2006/12/15 13:20:06  haselbac
! Modified calls RFLU_HashBuildKey to avoid warnings by ifort
!
! Revision 1.29  2006/03/25 21:50:34  haselbac
! Modified building of master bcell list for use with sype cases
!
! Revision 1.28  2005/08/21 16:08:36  haselbac
! Changed format for writing number of boundary cells
!
! Revision 1.27  2005/04/21 01:24:30  haselbac
! Fixed output format
!
! Revision 1.26  2005/03/23 17:09:25  haselbac
! Cosmetic changes only
!
! Revision 1.25  2005/03/10 02:32:12  haselbac
! Modified estimation of number of vertices for 2d grids
!
! Revision 1.24  2005/01/20 14:49:37  haselbac
! Added routines for building bface master and sorted bf2c lists
!
! Revision 1.23  2004/12/04 03:26:16  haselbac
! Adapted to new HashVertex routine, only renumber if have bfaces
!
! Revision 1.22  2004/11/03 17:00:35  haselbac
! Changed logic because of removal of vertFlag
!
! Revision 1.21  2004/11/03 16:04:01  haselbac
! Modified setting of nBVertEst so works if nBTrisTot=1
!
! Revision 1.20  2004/10/19 19:27:46  haselbac
! Substantial clean-up, added routines for local list for GENX
!
! Revision 1.19  2004/07/06 15:14:35  haselbac
! Adapted to changes in libflu and modflu, cosmetics
!                                                       
! Revision 1.18  2004/04/06 02:24:02  haselbac                                           
! Changed estimation of number of boundary vertices after problems                       
!
! Revision 1.17  2004/03/30 21:50:37  haselbac                                           
! Changed kludge to avoid problems with Randys nozzle grid                               
!
! Revision 1.16  2004/03/01 23:54:30  haselbac                                           
! Change kludge to be more conservative                                                  
!
! Revision 1.15  2004/02/02 22:50:40  haselbac                                           
! Changed kludge to fix problem with ONERA C0 case                                       
!
! Revision 1.14  2004/01/22 16:03:58  haselbac                                           
! Made contents of modules PRIVATE, only procs PUBLIC, to avoid errors on ALC 
! and titan  
!
! Revision 1.13  2003/07/22 02:03:21  haselbac                                           
! Added global%warnCounter                                                               
!
! Revision 1.12  2003/06/04 22:08:30  haselbac                                           
! Added Nullify routines, some cosmetics                                                 
!
! Revision 1.11  2003/05/06 12:57:37  haselbac                                           
! Removed NULLIFY of bvVirtual, breaks compilation                                       
!
! Revision 1.10  2003/05/06 01:06:20  haselbac                                           
! Added NULLIFY for bvVirtual                                                            
!
! Revision 1.9  2003/04/28 22:43:52  haselbac                                            
! Added routines for merged (master) bv list                                             
!
! Revision 1.8  2003/04/07 14:24:19  haselbac                                            
! Fixed formats and minor output bugs                                                    
!
! Revision 1.7  2003/03/27 14:30:53  haselbac                                            
! Added/modified routines for creating/building/destroying bv classes                    
!
! Revision 1.6  2003/03/25 19:14:02  haselbac                                            
! Fixed bug in printing string to screen and verbosity                                   
!
! Revision 1.5  2003/03/15 18:01:54  haselbac                                            
! Adaptation for || 1 (necessary for || gm)                                           
!
! Revision 1.4  2003/01/28 16:23:16  haselbac                                            
! Added creation, removed locally-numbered lists, BuildBVertexNormals now                
! in RFLU_ModGeometry                                                                    
!
! Revision 1.3  2003/01/08 21:08:31  haselbac                                            
! Fixed problems with double slashes in ifdefs (Absoft 8.0)                              
!
! Revision 1.2  2002/11/08 21:26:38  haselbac                                            
! Some cosmetics, now allow use within moving-grid cases                                 
!
! Revision 1.1  2002/10/27 19:08:52  haselbac                                            
! Initial revision                                                                       
!
! Revision 1.3  2002/10/12 14:55:27  haselbac                                            
! Bug fix: initialize nBVert                                                             
!
! Revision 1.2  2002/10/08 15:49:21  haselbac                                            
! {IO}STAT=global%error replaced by {IO}STAT=errorFlag - SGI problem                     
!
! Revision 1.1  2002/10/05 19:49:21  haselbac                                            
! Initial revision                                                                       
!
! ******************************************************************************

