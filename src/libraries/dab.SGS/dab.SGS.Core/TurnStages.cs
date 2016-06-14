using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core
{

    public enum TurnStages
    {
        /// <summary>
        /// Start of a turn. Player has done nothing yet
        /// </summary>
        Start,
        /// <summary>
        /// Before a judgement is being drawn (can use ward/negate card here)
        /// </summary>
        PreJudgement,
        /// <summary>
        /// Perform the judgement
        /// </summary>
        Judgement,
        /// <summary>
        /// Before drawing
        /// </summary>
        PreDraw,
        /// <summary>
        /// The actual action for drawing
        /// </summary>
        Draw,
        /// <summary>
        /// After a draw has happened
        /// </summary>
        PostDraw,
        /// <summary>
        /// An action for the player
        /// </summary>
        Play,
        
        /// <summary>
        /// Before the discard phase
        /// </summary>
        PreDiscard,
        /// <summary>
        /// The actual action for discarding
        /// </summary>
        Discard,
        /// <summary>
        /// After discarding
        /// </summary>
        PostDiscard,
        /// <summary>
        /// End of a player's turn. Add all extra turn stages before here.
        /// There is special logic that determines wrap-around for End (among 
        /// other things).
        /// </summary>
        End,

        /// <summary>
        /// When playing anythign that requires you to select a target(s)
        /// </summary>
        SelectTargets,

        /// <summary>
        /// When a player needs to react to a particular action (dodge, ward, attack in duel, etc)
        /// </summary>
        React,

        /// <summary>
        /// When the player reacts.
        /// </summary>
        Reacted,

        /// <summary>
        /// Player didn't react
        /// </summary>
        NoReaction,

        /// <summary>
        /// The notification that a player has died (players should select to peach/revive or not)
        /// </summary>
        PlayerDied,

        /// <summary>
        /// Player did not get enough peaches.
        /// </summary>
        PlayerEliminated,

        /// <summary>
        /// Player was revived
        /// </summary>
        PlayerRevived,

        /// <summary>
        /// We are prompting a player currently.
        /// </summary>
        Prompt,

    }
}
