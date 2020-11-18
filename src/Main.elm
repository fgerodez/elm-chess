module Main exposing (..)

import Browser
import Dict
import Html exposing (Html, div, h1, img, text)
import Html.Attributes exposing (dir, src, target)
import List
import List.Extra as List
import Maybe.Extra as Maybe



---- MODEL ----


type alias Model =
    {}


init : ( Model, Cmd Msg )
init =
    ( {}, Cmd.none )


type Color
    = White
    | Black


type PieceType
    = Pawn
    | King
    | Queen
    | Rook
    | Knight
    | Bishop


type alias Piece =
    { pieceType : PieceType
    , color : Color
    , position : Cell
    , hasMoved : Bool
    }


type alias Row =
    Int


type alias Col =
    Int


type alias Cell =
    ( Row, Col )


type alias Board =
    Dict.Dict Cell Piece


type Game
    = Game
        { player : Color
        , board : Board
        , gameHistory : List Game
        , lastMove : Maybe Move
        , availableMoves : List Move
        , isCheck : Bool
        , isCheckmate : Bool
        }


type alias Move =
    { piece : Piece
    , dst : Cell
    , moveType : MoveType
    }


type MoveType
    = Standard
    | PawnStart
    | EnPassant Piece
    | Castling Move


type alias Direction =
    ( Row, Col )



-- GAME FUNCTIONS --


newGame : Game
newGame =
    let
        board =
            startingBoard

        nextMoves =
            availableMoves board White False Nothing
    in
    Game
        { player = White
        , board = board
        , gameHistory = []
        , availableMoves = nextMoves
        , lastMove = Nothing
        , isCheck = False
        , isCheckmate = False
        }


availableMoves : Board -> Color -> Bool -> Maybe Move -> List Move
availableMoves board player isCheck lastMove =
    let
        allMoves piece =
            pieceCaptures board piece
                ++ pieceSteps board piece
                ++ enPassantMoves board lastMove
                ++ castlings

        castlings =
            if isCheck then
                []

            else
                castlingMoves board player

        simulatePieceMoves piece =
            List.map
                (\move -> ( move, applyMove board move ))
                (allMoves piece)

        isCheck_ simulation =
            isPlayerCheck simulation player
    in
    colorPieces board player
        |> List.concatMap simulatePieceMoves
        |> List.filterNot (isCheck_ << Tuple.second)
        |> List.map Tuple.first


playMove : Game -> Move -> Game
playMove (Game game) move =
    let
        nextPlayer =
            oppositeColor game.player

        nextBoard =
            applyMove game.board move

        lastMove =
            Just move

        isCheck =
            isPlayerCheck nextBoard nextPlayer

        nextMoves =
            availableMoves nextBoard nextPlayer isCheck lastMove

        isCheckmate =
            isCheck && List.length nextMoves == 0
    in
    Game
        { game
            | player = nextPlayer
            , board = nextBoard
            , gameHistory = game.gameHistory ++ [ Game game ]
            , availableMoves = nextMoves
            , lastMove = lastMove
            , isCheck = isCheck
            , isCheckmate = isCheckmate
        }


applyMove : Board -> Move -> Board
applyMove board move =
    let
        newBoard =
            movePiece board move.piece move.dst
    in
    case move.moveType of
        EnPassant target ->
            removePiece newBoard target

        Castling rookMove ->
            applyMove newBoard rookMove

        _ ->
            newBoard



-- BOARD FUNCTIONS --


startingBoard : Board
startingBoard =
    let
        row index =
            List.map (Tuple.pair index) (List.range 1 8)

        pawns =
            List.repeat 8 Pawn

        majorPieces =
            [ Rook
            , Knight
            , Bishop
            , King
            , Queen
            , Bishop
            , Knight
            , Rook
            ]

        rowPieces index color pieces =
            List.map2
                (\pieceType pos ->
                    { color = color
                    , pieceType = pieceType
                    , position = pos
                    , hasMoved = False
                    }
                )
                pieces
                (row index)

        piecesList =
            rowPieces 1 White majorPieces
                ++ rowPieces 2 White pawns
                ++ rowPieces 7 Black pawns
                ++ rowPieces 8 Black majorPieces

        insertPiece piece board =
            Dict.insert piece.position piece board
    in
    List.foldl insertPiece Dict.empty piecesList


isThreatenedBy : Board -> Cell -> Color -> Bool
isThreatenedBy board cell color =
    let
        pieces =
            colorPieces board color

        captureMoves =
            pieceCaptures board

        allCaptures =
            List.concatMap captureMoves pieces

        targetsCell move =
            move.dst == cell
    in
    List.any targetsCell allCaptures


isPlayerCheck : Board -> Color -> Bool
isPlayerCheck board color =
    let
        opponentColor =
            oppositeColor color

        king =
            findKing board color

        isAttacked piece =
            isThreatenedBy board piece.position opponentColor
    in
    Maybe.unwrap False isAttacked king


findKing : Board -> Color -> Maybe Piece
findKing board color =
    let
        isKing piece =
            piece.pieceType == King && piece.color == color
    in
    allPieces board
        |> List.filter isKing
        |> List.head


allPieces : Board -> List Piece
allPieces =
    Dict.values


colorPieces : Board -> Color -> List Piece
colorPieces board color =
    let
        pieces =
            allPieces board

        isRightColor piece =
            piece.color == color
    in
    List.filter isRightColor pieces


kingAtStartPos : Board -> Color -> Maybe Piece
kingAtStartPos board color =
    pieceAt board ( startRow color, 4 )


queenSideRook : Board -> Color -> Maybe Piece
queenSideRook board color =
    pieceAt board ( startRow color, 8 )


kingSideRook : Board -> Color -> Maybe Piece
kingSideRook board color =
    pieceAt board ( startRow color, 1 )


pieceAt : Board -> Cell -> Maybe Piece
pieceAt board cell =
    Dict.get cell board


isEmpty : Board -> Cell -> Bool
isEmpty board cell =
    pieceAt board cell == Nothing


isColor : Color -> Board -> Cell -> Bool
isColor color board cell =
    let
        targetPiece =
            pieceAt board cell

        isSameColor piece =
            piece.color == color
    in
    Maybe.unwrap False isSameColor targetPiece


oppositeColor : Color -> Color
oppositeColor color =
    if color == White then
        Black

    else
        White


movePiece : Board -> Piece -> Cell -> Board
movePiece board piece target =
    let
        newPiece =
            { piece
                | position = target
                , hasMoved = True
            }

        removedBoard =
            removePiece board piece

        finalBoard =
            Dict.insert target newPiece removedBoard
    in
    finalBoard


removePiece : Board -> Piece -> Board
removePiece board piece =
    Dict.remove piece.position board



-- CELL FUNCTIONS --


fromInt : { a | row : Int, col : Int } -> Maybe Cell
fromInt { row, col } =
    let
        isValid a =
            a > 0 && a < 9
    in
    if isValid row && isValid col then
        Just ( row, col )

    else
        Nothing


nextCell : Cell -> Direction -> Maybe Cell
nextCell ( srcRow, srcCol ) ( row, col ) =
    fromInt
        { row = srcRow + row
        , col = srcCol + col
        }


sideCells : Cell -> List Cell
sideCells ( row, col ) =
    let
        cells =
            [ fromInt
                { row = row
                , col = col + 1
                }
            , fromInt
                { row = row
                , col = col - 1
                }
            ]
    in
    Maybe.values cells


followDirection : Cell -> Direction -> List Cell
followDirection start dir =
    let
        firstCell =
            nextCell start dir

        follow cell =
            cell :: followDirection cell dir
    in
    Maybe.unwrap [] follow firstCell


nextEmptyCell : Board -> Cell -> Direction -> Maybe Cell
nextEmptyCell board start dir =
    let
        targetCell =
            nextCell start dir

        cellIsEmpty =
            isEmpty board
    in
    Maybe.filter cellIsEmpty targetCell


nextColorCell : Board -> Cell -> Color -> Direction -> Maybe Cell
nextColorCell board start color dir =
    let
        targetCell =
            nextCell start dir

        isRightColor =
            isColor color board
    in
    Maybe.filter isRightColor targetCell


findColorCell : Board -> Cell -> Color -> Direction -> Maybe Cell
findColorCell board start color dir =
    followDirection start dir
        |> List.dropWhile (isEmpty board)
        |> List.head
        |> Maybe.filter (isColor color board)


findEmptyCells : Board -> Cell -> Direction -> List Cell
findEmptyCells board start dir =
    let
        cells =
            followDirection start dir

        cellIsEmpty =
            isEmpty board
    in
    List.takeWhile cellIsEmpty cells



-- PIECE DIRECTION --


rookDirections : List Direction
rookDirections =
    [ ( 1, -1 )
    , ( 1, 0 )
    , ( 1, 1 )
    , ( 0, 1 )
    , ( 0, 1 )
    , ( -1, 1 )
    , ( -1, 0 )
    , ( -1, -1 )
    ]


knightDirections : List Direction
knightDirections =
    List.uniquePairs [ 2, 1 ]
        ++ List.uniquePairs [ 2, -1 ]
        ++ List.uniquePairs [ -2, 1 ]
        ++ List.uniquePairs [ -2, -1 ]


bishopDirections : List Direction
bishopDirections =
    [ ( 1, 1 )
    , ( 1, -1 )
    , ( -1, 1 )
    , ( -1, -1 )
    ]


kingDirections : List Direction
kingDirections =
    bishopDirections ++ rookDirections


queenDirections : List Direction
queenDirections =
    kingDirections


pawnCaptureDirections : Color -> List Direction
pawnCaptureDirections color =
    if color == White then
        [ ( 1, 1 ), ( 1, -1 ) ]

    else
        [ ( -1, 1 ), ( -1, -1 ) ]


pawnMoveDirection : Color -> Direction
pawnMoveDirection color =
    if color == White then
        ( 1, 0 )

    else
        ( -1, 0 )


pawnMoveNb : Bool -> Int
pawnMoveNb hasMoved =
    if hasMoved then
        1

    else
        2


startRow : Color -> Row
startRow color =
    if color == White then
        1

    else
        8


kingCastlingDirection : Direction
kingCastlingDirection =
    ( 0, -1 )


queenCastlingDirection : Direction
queenCastlingDirection =
    ( 0, 1 )



-- PIECE MOVES --


toStandardMove : Piece -> Cell -> Move
toStandardMove piece dst =
    { piece = piece
    , dst = dst
    , moveType = Standard
    }


toPawnStartMove : Piece -> Cell -> Move
toPawnStartMove piece dst =
    { piece = piece
    , dst = dst
    , moveType = PawnStart
    }


toEnPassantMove : Piece -> Piece -> Cell -> Move
toEnPassantMove piece opponent dst =
    { piece = piece
    , dst = dst
    , moveType = EnPassant opponent
    }


toCastlingMove : Piece -> Piece -> Cell -> Cell -> Move
toCastlingMove king rook kingDst rookDst =
    let
        rookMove =
            toStandardMove rook rookDst
    in
    { piece = king
    , dst = kingDst
    , moveType = Castling rookMove
    }


captureNext : Board -> Piece -> List Direction -> List Move
captureNext board piece dirs =
    let
        opponentColor =
            oppositeColor piece.color

        capture dir =
            nextColorCell board piece.position opponentColor dir
                |> Maybe.map (toStandardMove piece)
    in
    List.filterMap capture dirs


captureDirs : Board -> Piece -> List Direction -> List Move
captureDirs board piece dirs =
    let
        opponentColor =
            oppositeColor piece.color

        capture dir =
            findColorCell board piece.position opponentColor dir
                |> Maybe.map (toStandardMove piece)
    in
    List.filterMap capture dirs


castlingMoves : Board -> Color -> List Move
castlingMoves board color =
    let
        attackedCells =
            colorPieces board (oppositeColor color)
                |> List.concatMap (pieceCaptures board)
                |> List.map .dst

        king =
            findKing board color

        kingSide =
            Maybe.values [ king, kingSideRook board color ]

        queenSide =
            Maybe.values [ king, queenSideRook board color ]

        doCastling pieces dir =
            case pieces of
                [ kingPiece, rookPiece ] ->
                    castlingHelper board kingPiece rookPiece dir attackedCells

                _ ->
                    Nothing
    in
    Maybe.values
        [ doCastling kingSide kingCastlingDirection
        , doCastling queenSide queenCastlingDirection
        ]


castlingHelper : Board -> Piece -> Piece -> Direction -> List Cell -> Maybe Move
castlingHelper board king rook dir attackedCells =
    let
        path =
            findEmptyCells board king.position dir
                |> List.take 2

        isAttacked cell =
            List.member cell attackedCells

        isUnSafe =
            List.any isAttacked path
    in
    if rook.hasMoved || king.hasMoved || isUnSafe then
        Nothing

    else
        case path of
            [ rookDst, kingDst ] ->
                Just (toCastlingMove king rook kingDst rookDst)

            _ ->
                Nothing


enPassantMoves : Board -> Maybe Move -> List Move
enPassantMoves board lastMove =
    let
        enPassant move =
            case move.moveType of
                PawnStart ->
                    enPassantHelper board move

                _ ->
                    []
    in
    Maybe.unwrap [] enPassant lastMove


enPassantHelper : Board -> Move -> List Move
enPassantHelper board { piece, dst } =
    let
        opponentColor =
            oppositeColor piece.color

        isPlayerPawn p =
            p.color == opponentColor && p.pieceType == Pawn

        sidePawns =
            sideCells dst
                |> List.filterMap (pieceAt board)
                |> List.filter isPlayerPawn

        targetCell =
            nextCell dst (pawnMoveDirection opponentColor)

        toMove target =
            List.map (\pawn -> toEnPassantMove pawn piece target) sidePawns
    in
    Maybe.unwrap [] toMove targetCell


pieceCaptures : Board -> Piece -> List Move
pieceCaptures board piece =
    let
        pawnDirections =
            pawnCaptureDirections piece.color
    in
    case piece.pieceType of
        Rook ->
            captureDirs board piece rookDirections

        Knight ->
            captureNext board piece knightDirections

        Bishop ->
            captureDirs board piece bishopDirections

        King ->
            captureNext board piece kingDirections

        Queen ->
            captureDirs board piece queenDirections

        Pawn ->
            captureNext board piece pawnDirections


pieceSteps : Board -> Piece -> List Move
pieceSteps board piece =
    let
        stepNext dirs =
            List.filterMap (nextEmptyCell board piece.position) dirs
                |> List.map (toStandardMove piece)

        stepDirs dirs =
            List.concatMap (findEmptyCells board piece.position) dirs
                |> List.map (toStandardMove piece)

        pawnFirstStep dir =
            nextEmptyCell board piece.position dir
                |> Maybe.map (toStandardMove piece)

        pawnStart dir =
            pawnFirstStep dir
                |> Maybe.andThen (\{ dst } -> nextEmptyCell board dst dir)
                |> Maybe.map (toPawnStartMove piece)
    in
    case piece.pieceType of
        Rook ->
            stepDirs rookDirections

        Knight ->
            stepNext knightDirections

        Bishop ->
            stepDirs bishopDirections

        King ->
            stepNext kingDirections

        Queen ->
            stepDirs queenDirections

        Pawn ->
            [ pawnFirstStep, pawnStart ]
                |> List.andMap [ pawnMoveDirection piece.color ]
                |> Maybe.values
                |> List.take (pawnMoveNb piece.hasMoved)



---- UPDATE ----


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )



---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [ img [ src "/logo.svg" ] []
        , h1 [] [ text "Your Elm App is working!" ]
        ]



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = always Sub.none
        }
