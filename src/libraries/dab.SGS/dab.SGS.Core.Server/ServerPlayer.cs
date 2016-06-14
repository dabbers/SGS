using dab.SGS.Core.Cards.Playing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace dab.SGS.Core.Server
{
    public class ServerPlayer : Player
    {
        public ServerPlayer(string name, int maxhealth, Roles role) : base(name, maxhealth)
        {
            if (this.Role == Roles.King) this.MaxHealth++;

            this.Role = role;
        }

        public Roles Role { get; set; }
    }
}
