using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using dab.SGS.Core.Controllers;

namespace dab.SGS.Core.Cards.Playing.Basics
{
    public class WineBasicPlayingCard : BasicPlayingCard
    {
        public WineBasicPlayingCard(PlayingCardColor color, PlayingCardSuite suite, string details) 
            : base(color, suite, "Wine", details)
        {
        }
        
        /// <summary>
        /// This card is ONLY played when the player has died.
        /// </summary>
        /// <param name="sender"></param>
        /// <returns></returns>
        public override bool Play()
        {
            //if (this.Context.CurrentPlayStage.Stage == TurnStages.Play && sender.Count(p => p.IsPlayedAsAttack()) == 0 && 
            //    !this.Owner.WineInEffect && this.Owner.WinesLeft > 0)
            //{
            //    this.Owner.WinesLeft--;
            //    this.Owner.WineInEffect = true;
            //    this.Discard();
            //    return true;
            //}

            return base.Play();
        }
    }
}
