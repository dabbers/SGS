using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Cards.Playing;
using dab.SGS.Core.Cards.Playing.Basics;

namespace dab.SGS.Core.Controllers.Stage
{
    public abstract class TurnStageController : StageController
    {
        public TurnStageController(string display, TurnStages stage, Player start) : base(display, stage, start)
        {
            this.Stage = TurnStages.Start;
        }

        public override bool IsCardPlayable(PlayingCard card)
        {
            if (this.Stage == TurnStages.Play)
            {
                if (card.IsPlayedAsDodge()) return false;
                if (card.IsPlayedAsPeach() && card.Owner.CurrentHealth >= card.Owner.MaxHealth) return false;

                // Wine
                if (card.IsPlayedAsWine())
                {
                    if (true == card.Owner.WineInEffect || card.Owner.WinesLeft == 0) return false;
                }
                //        return ((this.Context.CurrentPlayStage.Stage == TurnStages.PlayerDied && this.Context.CurrentPlayStage.Source.Target == this.Owner
                //&& this.Owner.CurrentHealth < 1)

                return true;
            }

            return false;

        }
    }
}
