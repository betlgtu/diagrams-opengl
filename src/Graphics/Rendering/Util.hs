{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ViewPatterns #-}

module Graphics.Rendering.Util where

import qualified Data.ByteString as BS
import Data.Colour
import           Data.FileEmbed (embedFile)
import           System.FilePath ((</>))

import Diagrams.Attributes
import Diagrams.TwoD.Types
import Diagrams.ThreeD.Types

import Graphics.Rendering.OpenGL

import Data.Semigroup
import Data.Vinyl
import Control.Applicative
import qualified Linear as L

import Graphics.VinylGL
import Graphics.GLUtil
import Graphics.UI.GLFW

type Coord2d = "coord2d" ::: L.V2 GLfloat
type VColor  = "v_color" ::: L.V4 GLfloat
type MVP     = "mvp" ::: L.M44 GLfloat

coord2d :: Coord2d
coord2d = Field

vColor :: VColor
vColor  = Field

mvp :: MVP
mvp     = Field

data GlPrim = GlPrim { vertices :: [PlainRec [Coord2d, VColor]]
                     , elements :: [GLuint]
                     }

data Resources = Resources {
                             viewTransform :: Size -> PlainRec '[MVP]
                           , backgroundColor :: AlphaColour Double
                           , shaderProgram :: ShaderProgram
                           , buffer :: BufferedVertices [Coord2d, VColor]
                           , elementBuffer :: BufferObject
                           , elementCount :: GLsizei
                           }

instance Semigroup GlPrim where
    GlPrim v1 e1 <> GlPrim v2 e2 = GlPrim (v1 ++ v2) (e1 ++ e2') where
      e2' = map (+ (fromIntegral $ length v1)) e2

instance Monoid GlPrim where
    mappend = (<>)
    mempty  = GlPrim [] []

-- | Convert a haskell / diagrams color to OpenGL
--   TODO be more correct about color space
glColor :: (Real a, Floating a, Fractional b) => AlphaColour a -> Color4 b
glColor c = Color4 r g b a where
  (r,g,b,a) = r2fQuad $ colorToSRGBA c

v4Color :: (Real a, Floating a, Fractional b) => AlphaColour a -> L.V4 b
v4Color c = L.V4 r g b a where
  (r,g,b,a) = r2fQuad $ colorToSRGBA c


vSrc, fSrc :: BS.ByteString
-- TH arguments need to be literal strings, or defined in another module
-- In real code, the latter would be better to avoid platform-dependent '/'
vSrc = $(embedFile $ "src/Graphics/Rendering/util.v.glsl")
fSrc = $(embedFile $ "src/Graphics/Rendering/util.f.glsl")

initResources :: AlphaColour Double -> (Size -> PlainRec '[MVP]) -> GlPrim -> IO Resources
initResources bg tr ps = do
    Resources tr bg <$> simpleShaderProgramBS vSrc fSrc
        <*> bufferVertices (vertices ps)
        <*> fromSource ElementArrayBuffer (elements ps)
        <*> (pure . fromIntegral . length . elements $ ps)

unknitResources :: Resources -> IO ()
unknitResources (Resources _ _ sp (BufferedVertices vbo) ebo _) = do
    deleteObjectNames [vbo, ebo]
    deleteObjectName $ program sp

draw :: Resources -> Window -> IO ()
draw res win = do
    -- get some state for the transforms
    (width, height) <- getFramebufferSize win
    draw' res (Size (fromIntegral width) (fromIntegral height))

-- | The same as `draw` but allows for rendering into any bound framebuffer.
-- This should help when you want to render a diagram into a texture to be
-- used somewhere outside of a diagrams context.
draw' :: Resources -> Size -> IO ()
draw' (Resources m bg s vb e ct) size = do
    clearColor $= glColor bg
    clear [ColorBuffer]
    viewport $= (Position 0 0, size)
    -- actually set up OpenGL
    currentProgram $= (Just $ program s)
    enableVertices' s vb
    bindVertices vb
    setAllUniforms s $ m size
    bindBuffer ElementArrayBuffer $= Just e
    drawIndexedTris ct

fi :: (Integral a, Num b) => a -> b
fi = fromIntegral

r2f :: (Real r, Fractional f) => r -> f
r2f x = realToFrac x

r2fPr :: (Real r, Fractional f) => (r,r) -> (f,f)
r2fPr (a,b) = (r2f a, r2f b)

r2fQuad :: (Real r, Fractional f) => (r,r,r,r) -> (f,f,f,f)
r2fQuad (a,b,c,d) = (r2f a, r2f b, r2f c, r2f d)

shaderPath :: FilePath
shaderPath = "src/Graphics/Rendering/"

r2ToV2 :: R2 -> L.V2 GLfloat
r2ToV2 (unr2 -> (x, y)) = L.V2 (r2f x) (r2f y)

p2ToV2 :: P2 -> L.V2 GLfloat
p2ToV2 (unp2 -> (x, y)) = L.V2 (r2f x) (r2f y)

r2ToV3 :: R2 -> L.V3 GLfloat
r2ToV3 (unr2 -> (x, y)) = L.V3 (r2f x) (r2f y) 0

p2ToV3 :: P2 -> L.V3 GLfloat
p2ToV3 (unp2 -> (x, y)) = L.V3 (r2f x) (r2f y) 0

r3ToV3 :: R3 -> L.V3 GLfloat
r3ToV3 (unr3 -> (x, y, z)) = L.V3 (r2f x) (r2f y) (r2f z)

diagonalMatrix :: Real r => L.V3 r -> L.M33 GLfloat
diagonalMatrix (L.V3 x y z) = L.V3 (L.V3 (r2f x) 0 0) (L.V3 0 (r2f y) 0) (L.V3 0 0 (r2f z))

--zipRecs :: [Rec as f] -> [Rec bs f] -> [Rec (as ++ bs) f]
zipRecs :: [PlainRec as] -> [PlainRec bs] -> [PlainRec (as ++ bs)]
zipRecs = zipWith (<+>)
