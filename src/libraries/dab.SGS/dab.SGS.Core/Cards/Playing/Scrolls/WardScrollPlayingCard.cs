using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Controllers;

namespace dab.SGS.Core.Cards.Playing.Scrolls
{
    public class WardScrollPlayingCard : ScrollPlayingCard
    {
        public WardScrollPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string details) 
            : base(color, suite, "Ward", details)
        {
        }

        //public override bool IsPlayable()
        //{
        //    // can't use ward on delayed scrolls immediately. Only on prejudgement
        //    return (((this.Context.CurrentPlayStage.Stage == TurnStages.PlayScrollTargets) && (!(this.Context.CurrentPlayStage?.Cards.Activator.IsPlayedAsDelayScroll() ?? false)))
        //        || this.Context.CurrentPlayStage.Stage == TurnStages.PreJudgement);
        //}

    }
}
