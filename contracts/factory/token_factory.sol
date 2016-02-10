import 'auth/basic_authority.sol';
import 'data/balance_db.sol';
import 'factory/data_factory.sol';
import 'factory/auth_factory.sol';
import 'token/controller.sol';
import 'token/base.sol';
import 'token/frontend.sol';

contract DSTokenFactory {
    DSDataFactory _data;
    DSAuthFactory _auth;
    function DSTokenFactory( DSAuthFactory auth, DSDataFactory data ) {
        _data = data;
        _auth = auth;
    }
    function buildDSTokenController( DSBalanceDB bal_db, DSApprovalDB appr_db )
             external
             returns (DSTokenController)
    {
        var c = new DSTokenController( bal_db, appr_db );
        c.updateAuthority(msg.sender, false);
        return c;
    }
    function buildDSTokenFrontend( DSTokenController cont )
             external
             returns (DSTokenFrontend)
    {
        var c = new DSTokenFrontend( cont );
        c.updateAuthority(msg.sender, false);
        return c;
    }
    function buildDSTokenBase( uint initial_balance ) returns (DSTokenBase) {
        var c = new DSTokenBase(initial_balance);
        c.transfer(msg.sender, initial_balance);
        //c.updateAuthority(msg.sender, false);
        return c;
    }
    function buildDSTokenBasicSystem( DSBasicAuthority authority ) 
             returns( DSTokenFrontend frontend, DSBasicAuthority )
    {
        var balance_db = _data.buildDSBalanceDB();
        var approval_db = _data.buildDSApprovalDB();
        var controller = this.buildDSTokenController( balance_db, approval_db );
        frontend = this.buildDSTokenFrontend( controller );

        controller.setFrontend( frontend );

        balance_db.updateAuthority( authority, true );
        approval_db.updateAuthority( authority, true );
        controller.updateAuthority( authority, true );
        frontend.updateAuthority( authority, true );

        // The only data ops the controller does is `move` balances and `set` approvals.
        authority.setCanCall( controller, balance_db, bytes4(sha3("moveBalance(address,address,uint256)")), true );
        authority.setCanCall( controller, approval_db, bytes4(sha3("set(address,address,uint256)")), true );

        // The controller calls back to the forntend for 3 events.
        authority.setCanCall( controller, frontend, bytes4(sha3("eventTransfer(address,address,uint256)")), true );
        authority.setCanCall( controller, frontend, bytes4(sha3("eventApproval(address,address,uint256)")), true );

        // The frontend can call the proxy functions.
        authority.setCanCall( frontend, controller, bytes4(sha3("transfer(address,address,uint256)")), true );
        authority.setCanCall( frontend, controller, bytes4(sha3("transferFrom(address,address,address,uint256)")), true );
        authority.setCanCall( frontend, controller, bytes4(sha3("approve(address,address,uint256)")), true );

        authority.updateAuthority(msg.sender, false);

        return (frontend, authority);
    }
}
