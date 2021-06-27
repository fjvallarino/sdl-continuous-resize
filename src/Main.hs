{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Concurrent (forkIO, forkOS)
import Control.Concurrent.STM.TChan (TChan, newTChanIO, readTChan, writeTChan)
import Control.Monad (forever, unless)
import Control.Monad.STM (atomically)

import Foreign.C.Types

import SDL

import qualified Data.Set as Set
import qualified Graphics.Rendering.OpenGL as GL
import qualified NanoVG as VG

foreign import ccall unsafe "initGlew" glewInit :: IO CInt

main :: IO ()
main = do
  initialize [InitVideo]

  window <- createWindow "SDL Continuous Resize" WindowConfig {
    windowBorder = True,
    windowHighDPI = False,
    windowInputGrabbed = False,
    windowMode = Windowed,
    windowGraphicsContext = OpenGLContext customOpenGL,
    windowPosition = Wherever,
    windowResizable = True,
    windowInitialSize = V2 800 600,
    windowVisible = True
  }
  
  ctx1 <- glCreateContext window
  --ctx2 <- glCreateContext window
  _ <- glewInit

  channel <- newTChanIO

  addEventWatch $ \evt ->
    case eventPayload evt of
      WindowSizeChangedEvent sizeChangeData -> do
        --putStrLn $ "eventWatch windowSizeChanged: " ++ show sizeChangeData
        atomically $ writeTChan channel evt
        return ()
      _ -> return ()

  forkOS $ do
    glMakeCurrent window ctx1
    nvg <- VG.createGL3 (Set.fromList [VG.Antialias, VG.StencilStrokes])
    renderLoop window channel nvg

  appLoop window channel
  SDL.destroyWindow window
  SDL.quit
  where
    customOpenGL = OpenGLConfig {
      glColorPrecision = V4 8 8 8 0,
      glDepthPrecision = 24,
      glStencilPrecision = 8,
      glProfile = Core Normal 3 2,
      SDL.glMultisampleSamples = 1
    }

appLoop :: Window -> TChan Event -> IO ()
appLoop window channel = do
  evt <- waitEvent

  let shouldQuit = SDL.QuitEvent == eventPayload evt

  atomically $ writeTChan channel evt

  unless shouldQuit $
    appLoop window channel

renderLoop :: Window -> TChan Event -> VG.Context -> IO ()
renderLoop window channel nvg = do
  evt <- atomically $ readTChan channel

  let shouldQuit = SDL.QuitEvent == eventPayload evt

  case eventPayload evt of
    WindowSizeChangedEvent sizeChangeData -> do
      --putStrLn $ "waitEvent windowSizeChanged: " ++ show sizeChangeData
      let V2 nw nh = windowSizeChangedEventSize sizeChangeData
      let position = GL.Position 0 0
      let size = GL.Size nw nh

      GL.viewport GL.$= (position, size)
      return ()
    KeyboardEvent keyData -> do
      --print keyData
      return ()
    _ -> return ()

  V2 fbWidth fbHeight <- glGetDrawableSize window
  GL.clearColor GL.$= GL.Color4 0 0 0 1
  GL.clear [GL.ColorBuffer]
  VG.beginFrame nvg (realToFrac fbWidth) (realToFrac fbHeight) 1
  VG.fillColor nvg (VG.rgb 0 0 255)
  VG.ellipse nvg 200 200 100 100
  VG.fill nvg
  VG.endFrame nvg
  glSwapWindow window

  unless shouldQuit $
    renderLoop window channel nvg
