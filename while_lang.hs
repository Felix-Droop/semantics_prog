{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}
{-# LANGUAGE LambdaCase #-}

-- for the & operator (a.k.a. reverse application operator)
import Data.Function

------------------------- Basics -------------------------
type VariableName = String
type Number = Integer
type State = VariableName -> Number
------------------------- While language grammar -------------------------
data ArithmeticExp =
    NumberLiteral Number
    | Variable VariableName
    | Addition ArithmeticExp ArithmeticExp
    | Multiplication ArithmeticExp ArithmeticExp
    | Subtraction ArithmeticExp ArithmeticExp
    deriving (Show, Eq)

data BooleanExp =
    TrueLiteral
    | FalseLiteral
    | EqualTest ArithmeticExp ArithmeticExp
    | SmallerOrEqualTest ArithmeticExp ArithmeticExp
    | Negation BooleanExp
    | And BooleanExp BooleanExp
    deriving (Show, Eq)

data DV = MultipleV VariableName ArithmeticExp DV | EmptyDv
    deriving (Show, Eq)

data Statement =
    Assignment VariableName ArithmeticExp
    | Skip
    | Sequence Statement Statement
    | IfThenElse BooleanExp Statement Statement
    | WhileDo BooleanExp Statement
    | Block DV Statement
    deriving (Show, Eq)

------------------------- While Semantics -------------------------
arithmeticSemantic :: ArithmeticExp -> State -> Number
arithmeticSemantic (NumberLiteral n) state = n
arithmeticSemantic (Variable var) state = state var
arithmeticSemantic (Addition a1 a2) state =
    arithmeticSemantic a1 state + arithmeticSemantic a2 state
arithmeticSemantic (Multiplication a1 a2) state =
    arithmeticSemantic a1 state * arithmeticSemantic a2 state
arithmeticSemantic (Subtraction a1 a2) state =
    arithmeticSemantic a1 state - arithmeticSemantic a2 state

booleanSemantic :: BooleanExp -> State -> Bool
booleanSemantic TrueLiteral state = True
booleanSemantic FalseLiteral state = False
booleanSemantic (EqualTest a1 a2) state =
    arithmeticSemantic a1 state == arithmeticSemantic a2 state
booleanSemantic (SmallerOrEqualTest a1 a2) state =
    arithmeticSemantic a1 state <= arithmeticSemantic a2 state
booleanSemantic (Negation b) state = not (booleanSemantic b state)
booleanSemantic (And b1 b2) state =
    booleanSemantic b1 state && booleanSemantic b2 state

statementSemantic :: Statement -> State -> State
statementSemantic Skip s = s
statementSemantic (Assignment var a) s = substitutionState s var (arithmeticSemantic a s)
statementSemantic (Sequence stm1 stm2) s = statementSemantic stm2 (statementSemantic stm1 s)
statementSemantic (IfThenElse b stm1 stm2) s
    | booleanSemantic b s = statementSemantic stm1 s
    | otherwise = statementSemantic stm2 s
statementSemantic while@(WhileDo b stm) s
    | booleanSemantic b s = statementSemantic while (statementSemantic stm s)
    | otherwise = s
statementSemantic (Block dv stm) s = s
    & setLocalVariables dv
    & statementSemantic stm
    & resetLocalVariables dv s

-- initialize the local state with the given assignments
setLocalVariables :: DV -> State -> State
setLocalVariables EmptyDv s = s
setLocalVariables (MultipleV var aExp dv) s =
    setLocalVariables dv $ substitutionState s var (arithmeticSemantic aExp s)

-- set all the variables that occur in DV back to oldState
resetLocalVariables :: DV -> State -> State -> State
resetLocalVariables EmptyDv oldState resetState = resetState
resetLocalVariables (MultipleV var aExp dv) oldState resetState =
    resetLocalVariables dv oldState $ substitutionState resetState var (oldState var)

------------------------- Substitution Operators -------------------------
substitutionArithmetic :: ArithmeticExp -> VariableName -> ArithmeticExp -> ArithmeticExp
substitutionArithmetic (NumberLiteral n) var a_0 = NumberLiteral n
substitutionArithmetic (Variable existing_var) var a_0
    | existing_var == var = a_0
    | otherwise = Variable existing_var
substitutionArithmetic (Addition a_1 a_2) var a_0 =
    Addition (substitutionArithmetic a_1 var a_0) (substitutionArithmetic a_2 var a_0)
substitutionArithmetic (Multiplication a_1 a_2) var a_0 =
    Multiplication (substitutionArithmetic a_1 var a_0) (substitutionArithmetic a_2 var a_0)
substitutionArithmetic (Subtraction a_1 a_2) var a_0 =
    Subtraction (substitutionArithmetic a_1 var a_0) (substitutionArithmetic a_2 var a_0)

substitutionBoolean :: BooleanExp -> VariableName -> ArithmeticExp -> BooleanExp
substitutionBoolean TrueLiteral var a_0 = TrueLiteral
substitutionBoolean FalseLiteral var a_0 = FalseLiteral
substitutionBoolean (EqualTest a_1 a_2) var a_0 =
    EqualTest (substitutionArithmetic a_1 var a_0) (substitutionArithmetic a_2 var a_0)
substitutionBoolean (SmallerOrEqualTest a_1 a_2) var a_0 =
    SmallerOrEqualTest (substitutionArithmetic a_1 var a_0) (substitutionArithmetic a_2 var a_0)
substitutionBoolean (Negation b_1) var a_0 = Negation (substitutionBoolean b_1 var a_0)
substitutionBoolean (And b_1 b_2) var a_0 =
    And (substitutionBoolean b_1 var a_0) (substitutionBoolean b_2 var a_0)

substitutionState :: State -> VariableName -> Number -> State
substitutionState state var n param_var
    | var == param_var = n
    | otherwise = state param_var

------------------------- Test Examples -------------------------
-- (-13) + (5 * 8) - x
a :: ArithmeticExp
a = Subtraction
    (Addition
        (NumberLiteral (-13))
        (Multiplication (NumberLiteral 5) (NumberLiteral 8))
    )
    (Variable "x")

-- (y + 4) <= (9 - y)
b :: BooleanExp
b = SmallerOrEqualTest
    (Addition (Variable "y") (NumberLiteral 4))
    (Subtraction (NumberLiteral 9) (Variable "y"))

-- substitution examples
aSubstituted :: ArithmeticExp
aSubstituted = substitutionArithmetic a "x" (NumberLiteral 25)

-- (-13) + (5 * 8) - 25
aExpected :: ArithmeticExp
aExpected = Subtraction
    (Addition
        (NumberLiteral (-13))
        (Multiplication (NumberLiteral 5) (NumberLiteral 8))
    )
    (NumberLiteral 25)

bSubstituted :: BooleanExp
bSubstituted = substitutionBoolean b "y" $ Multiplication (NumberLiteral 3) (Variable "x")

-- ((3 * x) + 4) <= (9 - (3 * x))
bExpected :: BooleanExp
bExpected = SmallerOrEqualTest
    (Addition
        (Multiplication (NumberLiteral 3) (Variable "x"))
        (NumberLiteral 4)
    )
    (Subtraction
        (NumberLiteral 9)
        (Multiplication (NumberLiteral 3) (Variable "x"))
    )

-- y := 0; while (not x = 1) do (y := x * y; x := x - 1);
factorialExample :: Statement
factorialExample =
    Sequence
        (Assignment "y" $ NumberLiteral 1)
        (
            WhileDo (Negation $ EqualTest (Variable "x") (NumberLiteral 1))
            (
                Sequence
                    (Assignment "y" $ Multiplication (Variable "x") (Variable "y"))
                    (Assignment "x" $ Subtraction (Variable "x") (NumberLiteral 1))
            )
        )

-- y := 0; while y * 2 <= x do if y := y+1; if x = y * 2 then y:=1 else y:=0;
-- returns state with y=1 if x is even, else y=0
isEven :: Statement
isEven =
    Sequence
    (
        Assignment "y" $ NumberLiteral 0
    )
    (
        Sequence
        (
            WhileDo (SmallerOrEqualTest (Multiplication (Variable "y") (NumberLiteral 2)) (Variable "x"))
            (
                Assignment "y" (Addition (Variable "y") $ NumberLiteral 1)
            )
        )
        (
            IfThenElse (EqualTest (Variable "x") (Multiplication (Subtraction (Variable "y") (NumberLiteral 1)) $ NumberLiteral 2))
            (Assignment "y" $ NumberLiteral 1)
            (Assignment "y" $ NumberLiteral 0)
        )
    )

-- test state with all variables set to 1
oneState :: State
oneState _ = 1

-- returns state with z = x == y
isEqual :: Statement
isEqual =
    IfThenElse (EqualTest (Variable "x") (Variable "y"))
    (Assignment "z" $ NumberLiteral 1)
    (Assignment "z" $ NumberLiteral 0)

blockTest :: Statement
blockTest =
    Sequence
    (Assignment "x" $ NumberLiteral 2)
    (
        Block (MultipleV "x" (NumberLiteral 4) EmptyDv)
        (
            Assignment "y" $ Multiplication (Variable "x") $ NumberLiteral 3
        )
    )

------------------------- Main -------------------------
main :: IO()
main = do
    print "Test literal semantics"
    print $ arithmeticSemantic a oneState -- should be (-13) + (5 * 8) - 1 = 26
    print $ booleanSemantic b oneState --should be 5 <= 8 = True

    print "Test substitutions"
    print $ arithmeticSemantic aSubstituted oneState -- (-13) + (5 * 8) - 25 = 2
    print $ aSubstituted == aExpected -- should be True
    print $ booleanSemantic bSubstituted oneState -- 7 <= 6 = False
    print $ bSubstituted == bExpected -- should be True

    -- test lemma from exercise 2 (should both be True)
    print $
        arithmeticSemantic aSubstituted oneState
        == arithmeticSemantic a (substitutionState oneState "x" 25)
    print $
        booleanSemantic bSubstituted oneState
        == booleanSemantic b (substitutionState oneState "y" 3)

    print "Test statement semantics"
    -- test the factorial statement evaluation (as "x" = 6, this should equal fac(6)=720)
    --                        STATEMENT        INITIAL STATE   QUERY VARIABLE    TEST
    print $ statementSemantic factorialExample (\"x" -> 6)                "y" == 720
    print $ statementSemantic isEven           (\"x" -> 9)                "y" == 0
    print $ statementSemantic isEven           (\"x" -> 6)                "y" == 1
    print $ statementSemantic isEqual          (\case {"x" -> 6; _ -> 7}) "z" == 0

    print "Testing block semantics"
    let blockF = statementSemantic blockTest (\case {"x" -> 2; _ -> 0})
    print $ blockF "x" == 2
    print $ blockF "y" == 12
