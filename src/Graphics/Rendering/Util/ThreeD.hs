module Graphics.Rendering.Util.ThreeD where

import qualified Data.Vector.Storable as V

import Data.Colour

import Diagrams.ThreeD.Types
import Diagrams.Attributes
import Graphics.Rendering.OpenGL
import Graphics.Rendering.Util

data GlPrim3 = GlPrim3 {
  primMode :: PrimitiveMode,
  primColor :: (AlphaColour Double),
  primPts   :: [P3],
  primNormals :: [R3]
  }

draw3 :: GlPrim3 -> IO ()
draw3 (GlPrim3 mode c pts norms) = do
  color $ (glColor c :: Color4 GLfloat) -- all vertices same color
  V.unsafeWith (p3v pts) $ \ptr ->
    arrayPointer VertexArray $= VertexArrayDescriptor 3 Float 0 ptr
  V.unsafeWith (r3v norms) $ \ptr ->
    arrayPointer NormalArray $= VertexArrayDescriptor 3 Float 0 ptr
  drawArrays mode 0 ptCount where
    ptCount = fromIntegral $ length pts
    p3v = V.fromList . concatMap (map r2f . flat3 . unp3) :: [P3] -> V.Vector GLfloat
    r3v = V.fromList . concatMap (map r2f . flat3 . unr3) :: [R3] -> V.Vector GLfloat

flatP3 :: (Fractional a, Num a) => [P3] -> [a]
flatP3 = concatMap (flat3 . unp3)

flat3 :: (Fractional a, Num a) => (Double, Double, Double) -> [a]
flat3 (a,b,c) = [r2f a,r2f b,r2f c]