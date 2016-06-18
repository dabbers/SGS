using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;

namespace dab.SGS.Core
{
    [Flags]
    public enum UserPromptType
    {
        // Standard turn stuff: 
        //

        /// <summary>
        /// Select a skill(s) to use
        /// </summary>
        Skills = 1 << 0,

        //
        // End of standard skill stuff

        /// <summary>
        /// Choose a card from the player's hand
        /// </summary>
        CardsPlayerHand = 1 << 1,

        /// <summary>
        /// Choose a card from the player's play area
        /// </summary>
        CardsPlayerPlayArea = 1 << 2,

        /// <summary>
        /// Choose a card from the taget's hand
        /// </summary>
        CardsTargetHand = 1 << 3,

        /// <summary>
        /// Choose a card from the target's play area
        /// </summary>
        CardsTargetPlayArea = 1 << 4,

        /// <summary>
        /// Choose any card in the game (not deck or discard)
        /// </summary>
        AllCards = 1 << 5,

        /// <summary>
        /// The cards in the "holding area"
        /// </summary>
        HoldingArea = 1 << 6,

        /// <summary>
        /// Choose a target with configurable range M to N (min max)
        /// </summary>
        TargetRangeMN = 1 << 7,

        /// <summary>
        /// Select from a list of options
        /// </summary>
        Options = 1 << 8,

        /// <summary>
        /// Let the player use their shield's skill
        /// </summary>
        UseShieldSkill = 1 << 9,

        /// <summary>
        /// Let the player use their weapon's skill
        /// </summary>
        UseWeaponSkill = 1 << 10
    }


    public class UserPrompt
    {
        public List<Player> Targets{ get; set; }
        public List<PlayingCard> Cards { get; set; }


        public int MinTargets { get; set; }
        public int MaxTargets { get; set; }
        public int MinRange { get; set; }
        public int MaxRange { get; set; }
        public int MinCards { get; set; }
        public int MaxCards { get; set; }

        /// <summary>
        /// Player must play no cards, or exactly this # of cards. If 0, this is not a restriction.
        /// </summary>
        public int NoneOrMax { get; set; }

        public string Display { get; protected set; }
        public string[] Options { get; protected set; }

        public UserPromptType Type { get; protected set; }

        /// <summary>
        /// Create a user prompt of passed in types. Make sure to set min/max requirements if needed.
        /// </summary>
        /// <param name="type"></param>
        public UserPrompt(UserPromptType type)
        {
            this.Type = type;
            // Just default to something for now. Should set by caller
            this.MinTargets = this.MaxTargets = this.MinCards = this.MaxCards = this.MinRange = this.MaxRange = this.NoneOrMax = 0;
        }

        public UserPrompt(UserPromptType type, string display, string[] options) : this(type)
        {
            this.Display = display;
            this.Options = options;
        }
    }

}
