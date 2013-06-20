import Diagrams.Prelude hiding (doRender)
import Diagrams.Backend.OpenGL.ThreeD
import Diagrams.Backend.OpenGL.ThreeD.CmdLine
import Diagrams.ThreeD.Types

import Diagrams.ThreeD.Shapes

example :: Diagram OpenGL R3
example = sphere # translate (r3 (0.8, 0.8, -5)) # scale 0.5 # fc blue
          <> cylinder 

main :: IO ()
main = do
  --print . toDoc $ polarSphere 5 5
  --fileOutputDemo "ellipsoids.png" $ example
  defaultMain example