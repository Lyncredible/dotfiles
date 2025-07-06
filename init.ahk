#Requires AutoHotkey v2.0

!^Left::ResizeWindow("left")
!^Right::ResizeWindow("right")
!^Up::ResizeWindow("up")
!^Down::ResizeWindow("down")
!^m::ResizeWindow("max")
!^c::ResizeWindow("center")
!^o::ResizeWindow("middle")
!^[::ResizeWindow("left 2/3")
!^]::ResizeWindow("right 1/3")
!^,::ResizeWindow("left 1/3")
!^.::ResizeWindow("right 2/3")


ResizeWindow(direction) {
  winHandle := WinExist("A") ; The window to operate on

  ; Method 1: Current approach using GetMonitorInfo (recommended)
  ; This handles multi-monitor setups and all system UI elements correctly
  ;--------------------------------------------------------------------------
  monitorInfo := Buffer(40)
  NumPut("UInt", 40, monitorInfo)
  monitorHandle := DllCall("MonitorFromWindow", "Ptr", winHandle, "UInt", 0x2)

  ; Add error handling for monitor detection
  if (!monitorHandle) {
    ; Fallback to primary monitor if window handle is invalid
    monitorHandle := DllCall("MonitorFromPoint", "Int64", 0, "UInt", 0x2)
  }

  success := DllCall("GetMonitorInfo", "Ptr", monitorHandle, "Ptr", monitorInfo)

  ; Fallback to SystemParametersInfo if GetMonitorInfo fails
  if (!success) {
    workArea := Buffer(16)
    DllCall("SystemParametersInfo", "UInt", 0x30, "UInt", 0, "Ptr", workArea, "UInt", 0)
    workLeft := NumGet(workArea, 0, "Int")
    workTop := NumGet(workArea, 4, "Int")
    workRight := NumGet(workArea, 8, "Int")
    workBottom := NumGet(workArea, 12, "Int")

    ; For fallback, assume screen bounds match work area
    screenLeft := workLeft
    screenTop := workTop
    screenRight := workRight
    screenBottom := workBottom
  } else {
    screenLeft    := NumGet(monitorInfo,  4, "Int") ; Left
    screenTop     := NumGet(monitorInfo,  8, "Int") ; Top
    screenRight   := NumGet(monitorInfo, 12, "Int") ; Right
    screenBottom  := NumGet(monitorInfo, 16, "Int") ; Bottom

    workLeft      := NumGet(monitorInfo, 20, "Int") ; Left
    workTop       := NumGet(monitorInfo, 24, "Int") ; Top
    workRight     := NumGet(monitorInfo, 28, "Int") ; Right
    workBottom    := NumGet(monitorInfo, 32, "Int") ; Bottom
  }
  ;--------------------------------------------------------------------------

  workWidth    := workRight - workLeft
  workHeight   := workBottom - workTop

  ; Calculate screen dimensions for ultra-wide detection
  screenWidth  := screenRight - screenLeft
  screenHeight := screenBottom - screenTop

  ; Define layout configurations
  layouts := Map(
    "left", {x: 0, y: 0, w: 0.5, h: 1.0},
    "right", {x: 0.5, y: 0, w: 0.5, h: 1.0},
    "up", {x: 0, y: 0, w: 1.0, h: 0.5},
    "down", {x: 0, y: 0.5, w: 1.0, h: 0.5},
    "max", {x: 0, y: 0, w: 1.0, h: 1.0},
    "center", {x: 0.125, y: 0.125, w: 0.75, h: 0.75},
    "middle", {x: 0.167, y: 0, w: 0.667, h: 1.0},
    "left 2/3", {x: 0, y: 0, w: 0.667, h: 1.0},
    "right 1/3", {x: 0.667, y: 0, w: 0.333, h: 1.0},
    "left 1/3", {x: 0, y: 0, w: 0.333, h: 1.0},
    "right 2/3", {x: 0.333, y: 0, w: 0.667, h: 1.0}
  )

  ; Get layout configuration
  if (!layouts.Has(direction)) {
    return ; Invalid direction
  }

  layout := layouts[direction]

  ; Calculate position and size based on layout
  left := workLeft + Round(workWidth * layout.x)
  top := workTop + Round(workHeight * layout.y)
  width := Round(workWidth * layout.w)
  height := Round(workHeight * layout.h)

  ; Special handling for ultra-wide monitors (adjust center and middle layouts)
  ultraWideRatio := 21.0 / 9.0
  if (screenWidth / screenHeight >= ultraWideRatio) {
    if (direction == "center") {
      ; For ultra-wide, use a more reasonable center size
      width := Round(workWidth * 0.6)
      height := Round(workHeight * 0.8)
      left := workLeft + (workWidth - width) // 2
      top := workTop + (workHeight - height) // 2
    } else if (direction == "middle") {
      ; For ultra-wide, use golden ratio instead of 2/3
      goldenRatio := 0.618
      width := Round(workWidth * goldenRatio)
      left := workLeft + (workWidth - width) // 2
    }
  }

  WinGetPosEx(winHandle, &offsetLeft, &offsetTop, &offsetWidth, &offsetHeight)

  Style := WinGetStyle()
  if (Style & 0x20000) { ; WS_MINIMIZEBOX
    if (WinGetMinMax() != 0) {
      WinRestore()
    }
    if (direction == "max" && Style & 0x10000) { ; WS_MAXIMIZEBOX
      WinMaximize()
    } else {
      ; Apply offsets to compensate for DWM vs GetWindowRect differences
      ; The offsets represent: DWM_bounds - GetWindowRect_bounds
      ; So we need to adjust our target position by these offsets
      adjustedLeft := left - offsetLeft
      adjustedTop := top - offsetTop
      adjustedWidth := width - offsetWidth
      adjustedHeight := height - offsetHeight

      ; Ensure we don't get negative dimensions
      adjustedWidth := Max(adjustedWidth, 100)
      adjustedHeight := Max(adjustedHeight, 100)

      ; Alternative approaches (uncomment to use):
      ;----------------------------------------
      ; Method 1: Current approach (subtract offsets)
      ; adjustedLeft := left - offsetLeft
      ; adjustedTop := top - offsetTop
      ; adjustedWidth := width - offsetWidth
      ; adjustedHeight := height - offsetHeight
      ;
      ; Method 2: Add offsets (if the logic is inverted)
      ; adjustedLeft := left + offsetLeft
      ; adjustedTop := top + offsetTop
      ; adjustedWidth := width + offsetWidth
      ; adjustedHeight := height + offsetHeight
      ;
      ; Method 3: Only apply position offsets, ignore size offsets
      ; adjustedLeft := left - offsetLeft
      ; adjustedTop := top - offsetTop
      ; adjustedWidth := width
      ; adjustedHeight := height
      ;----------------------------------------

      WinMove(adjustedLeft, adjustedTop, adjustedWidth, adjustedHeight)
    }
  }
}

;------------------------------
;
; Function: WinGetPosEx
;
; Description:
;
;   Gets the position, size, and offset of a window. See the *Remarks* section
;   for more information.
;
; Parameters:
;
;   hWindow - Handle to the window.
;
;   X, Y, Width, Height - Output variables. [Optional] If defined, these
;       variables contain the coordinates of the window relative to the
;       upper-left corner of the screen (X and Y), and the Width and Height of
;       the window.
;
;   Offset_X, Offset_Y - Output variables. [Optional] Offset, in pixels, of the
;       actual position of the window versus the position of the window as
;       reported by GetWindowRect.  If moving the window to specific
;       coordinates, add these offset values to the appropriate coordinate
;       (X and/or Y) to reflect the true size of the window.
;
; Returns:
;
;   If successful, the address of a RECTPlus structure is returned.  The first
;   16 bytes contains a RECT structure that contains the dimensions of the
;   bounding rectangle of the specified window.  The dimensions are given in
;   screen coordinates that are relative to the upper-left corner of the screen.
;   The next 8 bytes contain the X and Y offsets (4-byte integer for X and
;   4-byte integer for Y).
;
;   Also if successful (and if defined), the output variables (X, Y, Width,
;   Height, Offset_X, and Offset_Y) are updated.  See the *Parameters* section
;   for more more information.
;
;   If not successful, FALSE is returned.
;
; Requirement:
;
;   Windows 2000+
;
; Remarks, Observations, and Changes:
;
; * Starting with Windows Vista, Microsoft includes the Desktop Window Manager
;   (DWM) along with Aero-based themes that use DWM.  Aero themes provide new
;   features like a translucent glass design with subtle window animations.
;   Unfortunately, the DWM doesn't always conform to the OS rules for size and
;   positioning of windows.  If using an Aero theme, many of the windows are
;   actually larger than reported by Windows when using standard commands (Ex:
;   WinGetPos, GetWindowRect, etc.) and because of that, are not positioned
;   correctly when using standard commands (Ex: gui Show, WinMove, etc.).  This
;   function was created to 1) identify the true position and size of all
;   windows regardless of the window attributes, desktop theme, or version of
;   Windows and to 2) identify the appropriate offset that is needed to position
;   the window if the window is a different size than reported.
;
; * The true size, position, and offset of a window cannot be determined until
;   the window has been rendered.  See the example script for an example of how
;   to use this function to position a new window.
;
; * 20150906: The "dwmapi\DwmGetWindowAttribute" function can return odd errors
;   if DWM is not enabled.  One error I've discovered is a return code of
;   0x80070006 with a last error code of 6, i.e. ERROR_INVALID_HANDLE or "The
;   handle is invalid."  To keep the function operational during this types of
;   conditions, the function has been modified to assume that all unexpected
;   return codes mean that DWM is not available and continue to process without
;   it.  When DWM is a possibility (i.e. Vista+), a developer-friendly messsage
;   will be dumped to the debugger when these errors occur.
;
; Credit:
;
;   Idea and some code from *KaFu* (AutoIt forum)
;
;-------------------------------------------------------------------------------
WinGetPosEx(hWindow, &Offset_Left := 0, &Offset_Top := 0, &Offset_Width := 0, &Offset_Height := 0) {
  Static S_OK := 0x0
        ,DWMWA_EXTENDED_FRAME_BOUNDS := 9
        ,RectPlus := Buffer(24)

  ;-- Get the window's dimensions
  ;   Note: Only the first 16 bytes of the RectPlus structure are used by the
  ;   DwmGetWindowAttribute and GetWindowRect functions.
  DWMRC := DllCall("dwmapi\DwmGetWindowAttribute",
      "Ptr",  hWindow,                                ;-- hwnd
      "UInt", DWMWA_EXTENDED_FRAME_BOUNDS,            ;-- dwAttribute
      "Ptr",  RectPlus,                               ;-- pvAttribute
      "UInt", 16)                                     ;-- cbAttribute

  if (DWMRC != S_OK)
  {
    OutputDebug "
      (ltrim join
      Function: %A_ThisFunc% -
      Unknown error calling "dwmapi\DwmGetWindowAttribute".
      RC=%DWMRC%,
      A_LastError=%A_LastError%.
      "GetWindowRect" used instead.
      )"

    ;-- Collect the position and size from "GetWindowRect"
    DllCall("GetWindowRect", "Ptr", hWindow, "Ptr", RectPlus)
  }

  ;-- Populate the output variables
  DWM_Left     := NumGet(RectPlus,  0, "Int")
  DWM_Top      := NumGet(RectPlus,  4, "Int")
  DWM_Right    := NumGet(RectPlus,  8, "Int")
  DWM_Bottom   := NumGet(RectPlus, 12, "Int")

  ;-- If DWM is not used (older than Vista or DWM not enabled), we're done
  if (DWMRC != S_OK)
    Return

  ;-- Collect dimensions via GetWindowRect
  Rect := Buffer(16)
  DllCall("GetWindowRect", "Ptr", hWindow, "Ptr", Rect)
  GMR_Left   := NumGet(Rect, 0, "Int")
  GMR_Top    := NumGet(Rect, 4, "Int")
  GMR_Right  := NumGet(Rect, 8, "Int")
  GMR_Bottom := NumGet(Rect, 12, "Int")

  ;-- Calculate offsets and update output variables
  Offset_Left   := DWM_Left   - GMR_Left
  Offset_Top    := DWM_Top    - GMR_Top
  Offset_Width  := (DWM_Right - DWM_Left) - (GMR_Right - GMR_Left)
  Offset_Height := (DWM_Bottom - DWM_Top) - (GMR_Bottom - GMR_Top)
}
