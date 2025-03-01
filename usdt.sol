// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface pour USDT (Tether)
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LoanWithCollateral {
    IERC20 public usdt; // Contrat USDT
    address public owner; // Le propriétaire du contrat (le prêteur)

    struct Loan {
        uint256 loanAmount; // Montant du prêt
        uint256 collateralAmount; // Montant de la garantie en USDT
        uint256 repaymentAmount; // Montant à rembourser (incluant les intérêts)
        uint256 dueDate; // Date d'échéance du remboursement
        address borrower; // Emprunteur
        bool isRepaid; // Statut du remboursement
        bool isResolved; // Statut de la résolution
    }

    uint256 public loanCounter;
    mapping(uint256 => Loan) public loans;

    event LoanCreated(uint256 loanId, address borrower, uint256 loanAmount, uint256 collateralAmount, uint256 repaymentAmount, uint256 dueDate);
    event LoanRepaid(uint256 loanId);
    event LoanDefaulted(uint256 loanId);
    event CollateralClaimed(uint256 loanId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Seul le propriétaire peut exécuter cette action.");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(msg.sender == loans[loanId].borrower, "Seul l'emprunteur peut exécuter cette action.");
        _;
    }

    modifier loanExists(uint256 loanId) {
        require(loanId < loanCounter, "Ce prêt n'existe pas.");
        _;
    }

    constructor(address _usdtAddress) {
        usdt = IERC20(_usdtAddress);
        owner = msg.sender;
    }

    // Création d'un prêt avec une garantie en USDT
    function createLoan(uint256 _loanAmount, uint256 _collateralAmount, uint256 _repaymentAmount, uint256 _dueDate) external {
        // Vérification de la quantité de collatéral envoyée par l'emprunteur
        require(usdt.transferFrom(msg.sender, address(this), _collateralAmount), "Échec du transfert de collatéral.");

        loans[loanCounter] = Loan({
            loanAmount: _loanAmount,
            collateralAmount: _collateralAmount,
            repaymentAmount: _repaymentAmount,
            dueDate: _dueDate,
            borrower: msg.sender,
            isRepaid: false,
            isResolved: false
        });

        emit LoanCreated(loanCounter, msg.sender, _loanAmount, _collateralAmount, _repaymentAmount, _dueDate);

        loanCounter++;
    }

    // Rembourser le prêt
    function repayLoan(uint256 loanId) external payable onlyBorrower(loanId) loanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(!loan.isRepaid, "Le prêt a déjà été remboursé.");
        require(block.timestamp <= loan.dueDate, "Le délai de remboursement est dépassé.");
        require(msg.value == loan.repaymentAmount, "Montant de remboursement incorrect.");

        // Transfert du montant du prêt au prêteur
        payable(owner).transfer(msg.value);

        // Remboursement du collatéral à l'emprunteur
        require(usdt.transfer(loan.borrower, loan.collateralAmount), "Échec du remboursement du collatéral.");

        loan.isRepaid = true;
        emit LoanRepaid(loanId);
    }

    // Si l'emprunteur ne rembourse pas, le prêteur peut réclamer la garantie
    function claimCollateral(uint256 loanId) external onlyOwner loanExists(loanId) {
        Loan storage loan = loans[loanId];
        require(block.timestamp > loan.dueDate, "Le prêt n'est pas encore dû.");
        require(!loan.isRepaid, "Le prêt a déjà été remboursé.");
        require(!loan.isResolved, "Le prêt a déjà été résolu.");

        // Le prêteur peut réclamer la garantie en cas de défaut de remboursement
        loan.isResolved = true;

        // Le prêteur reçoit le collatéral en USDT
        require(usdt.transfer(owner, loan.collateralAmount), "Échec du transfert de collatéral.");

        emit CollateralClaimed(loanId);
    }

    // Vérifier les détails d'un prêt
    function getLoanDetails(uint256 loanId) external view loanExists(loanId) returns (
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 repaymentAmount,
        uint256 dueDate,
        address borrower,
        bool isRepaid,
        bool isResolved
    ) {
        Loan memory loan = loans[loanId];
        return (
            loan.loanAmount,
            loan.collateralAmount,
            loan.repaymentAmount,
            loan.dueDate,
            loan.borrower,
            loan.isRepaid,
            loan.isResolved
        );
    }
}
