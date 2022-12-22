import Yatima.Datatypes.Store
import Yatima.Lean.Utils
import Yatima.Converter.ConvertError
import YatimaStdLib.RBMap
import YatimaStdLib.Ord

namespace Yatima

namespace Converter

open Std (RBMap)

/--
`RecrCtx` contains information for the reconstruction of (mutual) definitions
and inductives. Each item (identified by an index) in the recursive context is
mapped to its constant index and its name. In the case of definitions, the items
are also identified by a second index that indicates their position among weakly
equal definitions.
-/
abbrev RecrCtx := RBMap (Nat × Option Nat) (Nat × Name) compare

/--
The reader structure for the `ConvertM` monad contains:
* `store`, which has the initial data of constants to be extracted
* `recrCtx` of type `RecrCtx`
* `bindDepth`, which says how many `lam`, `pi` or `letE` binders we've gone
through recursively; used to implement constant replacement of free variables
-/
structure ConvertEnv where
  store     : IR.Store
  recrCtx   : RecrCtx
  bindDepth : Nat
  deriving Inhabited

/-- Starts a new `ConvertEnv` with a given `Yatima.IR.Store` -/
def ConvertEnv.init (store : IR.Store) : ConvertEnv :=
  ⟨store, default, 0⟩

/--
Contains the progress of the conversion process.

* `univCache` and `constCache` are optimization means
* `tcStore` is the actual output of the conversion, whose order is pre-encoded based on the store
* `constsIdx` contains auxiliary data to recover a constant index by its name using the order in `consts`
-/
structure ConvertState where
  univCache  : RBMap IR.BothUnivCid TC.Univ compare
  constCache : RBMap IR.BothConstCid TC.ConstIdx compare
  tcStore    : TC.Store
  constsIdx  : RBMap Name TC.ConstIdx compare
  deriving Inhabited

/-- The monad in which conversion takes place -/
abbrev ConvertM := ReaderT ConvertEnv $ EStateM ConvertError ConvertState

/-- Runs a function in `ConvertM` given a `ConvertEnv` and a `ConvertState` -/
def ConvertM.run (env : ConvertEnv) (ste : ConvertState) (m : ConvertM α) :
    Except ConvertError ConvertState :=
  match EStateM.run (ReaderT.run m env) ste with
  | .ok _ stt  => .ok stt
  | .error e _ => .error e

/-- Extracts `x` from `some x` and throws an error otherwise -/
def ConvertM.unwrap : Option α → ConvertM α :=
  Option.option (throw .irError) pure

/-- Runs a computation with `bindDepth` reset to `0` -/
def withResetBindDepth : ConvertM α → ConvertM α :=
  withReader $ fun e => { e with bindDepth := 0 }

/-- Runs a computation with a certain `RecrCtx` -/
def withRecrs (recrCtx : RecrCtx) : ConvertM α → ConvertM α :=
  withReader $ fun e => { e with recrCtx }

/-- Runs a computation with `bindDepth` increased by `1` -/
def withNewBind : ConvertM α → ConvertM α :=
  withReader $ fun e => { e with bindDepth := e.bindDepth + 1 }

namespace Converter

namespace Yatima