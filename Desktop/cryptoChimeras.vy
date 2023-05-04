# pragma @version ^0.2.4

###############################################################
# To develop this contract I took ideas from CryptoZombies 
# @ https://cryptozombies.io/ the idea is to develop something
# similar but in vyper

# CryptoChimeras is a game where hunters use chimeras to fight.
# The chimera that win will mutate in a new chimera using The
# DNA of the winner and the loser chimera. 
# This is why it is called Chimera :)
#
# HOW IT WORKS:
# 1 - Hunters are created when entering a name and 1 chimera 
# gets assigned. They can have multiple chimeras
# 2 - Chimeras get random HP. There can be many copy of one
# 3 - Hunters can fight each other. To do so they have to bid 
# 4 - The winner gets the bid.
# 5 - TODO Winning chimera gets evolved based on DNA 
###############################################################

# Events for the front-end
event newChimera:
    chimeraCount: uint256
    name: String[32]
    dna: uint256
    HP: uint256

event newHunter:
    name: String[32]
    chimeraName: String[32]

# number used for generating wild chimeras
numberForNames : uint256

# bid value for fights
fightBid : uint256

# Count # of hunters and chimeras
hunterCount : public(int128)
chimeraCount: public(uint256)

# Set up the modulus to cut every DNA integer to be 16-digits
dnaModulus : constant(uint256) = 10 ** 16

# List of possible chimera's names
mythologyNames : HashMap[uint256, String[32]]

# Quite hard to create lists, but we can use a constructor
@ external
def __init__():
   self.mythologyNames[0] = 'Hydra'  
   self.mythologyNames[1] = 'Cerbero'
   self.mythologyNames[2] = 'Sfinx'
   self.mythologyNames[3] = 'Pegasus' 
   self.mythologyNames[4] = 'Centaur'
   self.mythologyNames[5] = 'Siren'
   # TODO Add more in later implemetations 5 are enough for testing


# Create a chimera
struct Chimera:
    name : String[32]
    dna : uint256
    HP : uint256
    wins : uint256
    looses : uint256
    fights : uint256

# Create a Hunter
struct Hunter:
    name : String[32]
    hunterAddress : address

###############################################################   
# Lists to keep track of chimeras and Hunters

# id -> chimera
chimerasList : public(HashMap[uint256, Chimera])
# name -> id
chimeraNameToID : public(HashMap[String[32], uint256])
# name -> address
hunterNameToAdd : public(HashMap[String[32], address])
# name -> hunter (for future implementation)
huntersList : public(HashMap[String[32], Hunter])
# hunter address -> (id -> chimera)
hunterToChimera : public(HashMap[address, HashMap[uint256, Chimera]])
# id -> address (address that owns the chimera, for future implementation)
chimeraToHunter : public(HashMap[uint256, address])
# hunter address -> id (number of chiimeras owned, for future implementation)
hunterChimeraCount : public(HashMap[address, uint256])
# id -> Hunter
hunterList2 : public(HashMap[int128, Hunter])
###############################################################   


# The mutability level of this function is "pure" because
# does not read from the contract state or environment variable.
# To generate our number we use hash function keccak256
@pure   
@internal
def _generateRandomDNA(_name: String[32]) -> uint256:
    rand: uint256 = convert(keccak256(_name), uint256)
    return rand % dnaModulus


@internal
def _generateRandomValue() -> uint256:
    rand: uint256 = convert(keccak256(convert(self.chimeraCount, bytes32)), uint256)
    return rand % dnaModulus


@internal
def _checkHunterName(hunterName: String[32]) -> bool:
    ind : int128 = self.hunterCount
    # we assume 2 players
    for i in range(2):
        if self.hunterList2[i].name == hunterName:
            return True
    return False


# Use msg.sended to keep track of every element
@internal
def _setSender(mySender: address, name: String[32], chimeraName: String[32]):

   # Update ownership of chimeras with hunters
    self.chimeraToHunter[self.chimeraNameToID[chimeraName]] = mySender

    # Keep count of chimeras for each hunter
    self.hunterChimeraCount[mySender] += 1

    # Keep track of hunters
    self.hunterNameToAdd[name] = mySender 


# Create chimeras and add it to the list.
# Internal to access to it only from the contract
@internal
def _createChimera(_name: String[32]) -> Chimera:
    
    # Generate a Chimera DNA
    randDna: uint256 = self._generateRandomDNA(_name)
    
    # Generate a Chimera HP with a limit of 500
    randHP: uint256 = randDna % 500
    
    # Create a Chimera and add it to the list use the count as an id 
    createdChimera: Chimera = Chimera({name: _name, dna: randDna, HP: randHP, wins: 0, looses: 0, fights: 0})

    self.chimerasList[self.chimeraCount] = createdChimera
    self.chimeraNameToID[_name] = self.chimeraCount
    self.chimeraCount += 1


    # Signal to the front-end
    log newChimera(self.chimeraCount, _name, randDna, randHP)
    
    return createdChimera


# We to create this function because we can't use msg.sender from an interal function.
# Otherwise we could have created an Hunter from the createChimera function
@external 
def _createHunter(_name: String[32], _chimeraName: String[32]):

    # check if names already exist
    assert not self._checkHunterName(_name)
    createdHunter: Hunter = Hunter({name: _name, hunterAddress: msg.sender})
    createdChimera: Chimera = self._createChimera(_chimeraName)

    # collect huntes based on names and based on IDs
    self.huntersList[_name] = createdHunter
    self.hunterList2[self.hunterCount] = createdHunter

    # Keep track of new hunters
    self.hunterCount +=1

    # keep track of hunter's chimeras
    self.hunterToChimera[msg.sender][self.chimeraNameToID[_chimeraName]] = createdChimera

    # Used for: Update ownership of chimeras, 
    # Keep count of chimeras for each hunter,
    # Keep track of hunter
    self._setSender(msg.sender, _name, _chimeraName)

   # Signal to the front-end
    log newHunter(_name, _chimeraName) 


# Hunt a random chimera. Right now is set up in a way that chimeras
# are hunt incrementaly starting from Hydra up to Siren
@external
def huntChimeras(hunterName: String[32], chimeraName: String[32]):

    # let's generate a randon number to randomly create one of the 6 chimeras
    randomValue : uint256 = self._generateRandomValue()

    # Cenerate 2 rand numebers to be used in the odds of hunting a wild chimera
    # Initially a hunter has only one chimera so it has less chances to get a 
    # wild chimera siince it can generate a rand name frrom only one chimera 
    randNumberHunter : uint256 = self._generateRandomDNA(hunterName)
    randNumberChimera : uint256 = self._generateRandomDNA(chimeraName)
    rand1: uint256 = randNumberHunter
    rand2: uint256 = randNumberChimera

    # Decide if a wild chimera gets hunted
    if (rand1 <= rand2):
        wildChimera : Chimera = self._createChimera(self.mythologyNames[randomValue % 6]) 
        # keep track of hunter's chimeras
        self.hunterToChimera[msg.sender][self.chimeraCount] = wildChimera
        # Used for: Update ownership of chimeras, 
        # Keep count of chimeras for each hunter,
        # Keep track of hunters
        self._setSender(msg.sender, hunterName, wildChimera.name)


# Fight another Hunter to get a new Chimera and a reward.
@external
@payable
def fightAnotherHunter(hunterName1: String[32], chimeraName1: String[32], hunterName2: String[32], chimeraName2: String[32]):
    # Create a random number for both hunters using their names
    # Hunter 1
    randNumberHunter1 : uint256 = self._generateRandomDNA(hunterName1)
    randNumberChimera1 : uint256 = self._generateRandomDNA(chimeraName1)
    firstChimeraDNA : uint256 =self.chimerasList[self.chimeraNameToID[chimeraName1]].dna 
    rand1: uint256 = randNumberHunter1 + randNumberChimera1 + firstChimeraDNA
    # Hunter 2
    randNumberHunter2 : uint256 = self._generateRandomDNA(hunterName2)
    randNumberChimera2 : uint256 = self._generateRandomDNA(chimeraName2)
    secondChimeraDNA : uint256 =self.chimerasList[self.chimeraNameToID[chimeraName2]].dna 
    rand2: uint256 = randNumberHunter2 + randNumberChimera2 + secondChimeraDNA

    # Set the bit for the fight
    self.fightBid = msg.value

    # TODO implenet a a way to mix up chimeras' DNAs to get a new chimeras. 
            
    # Gets first and second hunter and chimera address and id
    firstHunterAdd : address = self.hunterNameToAdd[hunterName1]
    firstChimeraID : uint256 =self.chimeraNameToID[chimeraName1]
    secondHunterAdd : address = self.hunterNameToAdd[hunterName2]
    secondChimeraID : uint256 =self.chimeraNameToID[chimeraName2]

    # Chimera 2 wins
    if (rand1 < rand2):
        # Hunter 2 gets the reward
        send(self.hunterNameToAdd[hunterName2], self.fightBid)

        # update chimera'a stats
        self.hunterToChimera[secondHunterAdd][secondChimeraID].wins += 1
        self.hunterToChimera[secondHunterAdd][secondChimeraID].fights += 1

        self.hunterToChimera[firstHunterAdd][firstChimeraID].looses += 1
        self.hunterToChimera[firstHunterAdd][firstChimeraID].fights += 1
    else:
    # chimera 1 wins
        # Hunter 1 gets the reward
        send(self.hunterNameToAdd[hunterName1], self.fightBid)

        # update chimera'a stats
        self.hunterToChimera[firstHunterAdd][firstChimeraID].wins += 1
        self.hunterToChimera[firstHunterAdd][firstChimeraID].fights += 1

        self.hunterToChimera[secondHunterAdd][secondChimeraID].looses += 1
        self.hunterToChimera[secondHunterAdd][secondChimeraID].fights += 1

